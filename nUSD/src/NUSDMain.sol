//SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.18;

import {NUSD} from "./NUSD.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

contract NUSDMain is ReentrancyGuard{
    error NUSDMain__NeedsGreaterThanZero();
    error NUSDMain__TransferFailed();
    error NUSDMain__BreaksHealthFactor(uint256 userHealthFactor);
    error NUSDMain__MintFailed();
    error NUSDMain__HealthFactorOk();
    error NUSDMain__HealthFactorNotImproved();

    using OracleLib for AggregatorV3Interface;
    address public priceFeedAddress;
    NUSD private immutable iNusd;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // only receive 50% of Eth value in nUSD 
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    event EthDeposited(address indexed user,uint256 indexed amount);
    event EthRedeemed(address indexed redeemedFrom, address indexed redeemedTo,uint256 amountEth);

    /// @dev Amount of ETH deposited by user
    mapping(address user => uint256 amount) private s_ethDeposited;
    /// @dev Amount of NUSD minted by user
    mapping(address user => uint256 amountNUSDMinted) private s_NUSDMinted;

    modifier moreThanZero(uint256 amount){
        if(amount == 0){
            revert NUSDMain__NeedsGreaterThanZero();
        }
        _;
    }

    constructor(address _priceFeedAddress,address nUsdAddress){
        priceFeedAddress = _priceFeedAddress;
        iNusd = NUSD(nUsdAddress);
    }

    //External Functions

    function depositEthAndMint() external payable{
        depositEth();
        uint256 amountNusdToMint = _calculateAmountToMint(msg.value);
        mintNusd(amountNusdToMint);
    }

    function redeemEthForNusd(uint256 _amountNusdToBurn) external payable{
        uint256 amountNusdToBurn = _amountNusdToBurn * PRECISION;      
        uint256 amountEth = getEthAmountFromUsd(amountNusdToBurn);
        burnNusd(amountNusdToBurn);
        redeemEth(amountEth);
    }

    function redeemEth(uint256 amountEth)
        public
        moreThanZero(amountEth)
        nonReentrant
    {
        _redeemEth(msg.sender, msg.sender,amountEth);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnNusd(uint256 amount) public moreThanZero(amount){
        _burnNusd(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate(address user,uint256 debtToCover) 
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if(startingUserHealthFactor >= MIN_HEALTH_FACTOR){
            revert NUSDMain__HealthFactorOk();
        }
        uint256 ethAmountFromDebtCovered = getEthAmountFromUsd(debtToCover);
        uint256 bonusEth = (ethAmountFromDebtCovered * LIQUIDATION_BONUS)/LIQUIDATION_PRECISION;
        uint256 totalEthToRedeem = ethAmountFromDebtCovered + bonusEth;
        _redeemEth(user, msg.sender, totalEthToRedeem);
        _burnNusd(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if(endingUserHealthFactor <= startingUserHealthFactor){
            revert NUSDMain__HealthFactorNotImproved();
        }
    }

    //Public Functions

    function mintNusd(uint256 amountNusdToMint) public moreThanZero(amountNusdToMint) nonReentrant returns(uint256){
        s_NUSDMinted[msg.sender] += amountNusdToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = iNusd.mint(msg.sender,amountNusdToMint);
        if(!minted){
            revert NUSDMain__MintFailed();
        }
        return (iNusd.balanceOf(msg.sender));
    }

    function depositEth()
        public
        payable
        moreThanZero(msg.value)
        nonReentrant
    {
        s_ethDeposited[msg.sender] += msg.value;
        emit EthDeposited(msg.sender,msg.value);
    }

    //Private & Internal Functions

    function _redeemEth(
        address from,
        address to,
        uint256 amountEth) private {
        s_ethDeposited[from] -= amountEth;
        emit EthRedeemed(from,to,amountEth);
        (bool success,) = (payable(msg.sender)).call{value:amountEth}("");
        if(!success){
            revert NUSDMain__TransferFailed();
        }
    }

    function _burnNusd(uint256 amountNusdToBurn,address onBehalfOf, address nUsdFrom) private {
        s_NUSDMinted[onBehalfOf] -= amountNusdToBurn;
        bool success = iNusd.transferFrom(nUsdFrom, address(this), amountNusdToBurn);
        if(!success){
            revert NUSDMain__TransferFailed();
        }
        iNusd.burn(amountNusdToBurn);
    }

    function _getAccountInformation(address user)
        private
        view
        returns(uint256 totalNusdMinted, uint256 ethValueInUsd)
    {
        totalNusdMinted = s_NUSDMinted[user];
        ethValueInUsd = getAccountEthValue(user);
    }

    function _healthFactor(address user) private view returns(uint256){
        (uint256 totalNusdMinted, uint256 ethValueInUsd)= _getAccountInformation(user);
        return _calculateHealthFactor(totalNusdMinted,ethValueInUsd);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view{
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR){
            revert NUSDMain__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _getUsdValue(uint256 amount) private view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (,int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // The returned valur is in 8 decimals
        return (uint256(price) * amount)/PRECISION;
    }

    function _calculateHealthFactor(uint256 totalNusdMinted, uint256 ethValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalNusdMinted == 0) return type(uint256).max;
        uint256 ethAdjustedForThreshold = (ethValueInUsd * ADDITIONAL_FEED_PRECISION * LIQUIDATION_THRESHOLD) / 100;
        return (ethAdjustedForThreshold * 1e18) / totalNusdMinted;
    }

    function _calculateAmountToMint(uint256 amountEth) public view returns(uint256){
        uint256 ethUsdValue = _getUsdValue(amountEth);
        return ((ethUsdValue * ADDITIONAL_FEED_PRECISION)/2);
    }


    ///////////////////////////////////////
    // Public & External View Functions ///
    ///////////////////////////////////////

    function calculateHealthFactor(uint256 totalNusdMinted, uint256 ethValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalNusdMinted, ethValueInUsd);
    }

    function getEthAmountFromUsd(uint256 usdAmountInWei) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (,int256 price,,,) = priceFeed.latestRoundData();
        // The returned valur is in 18 decimals
        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getAccountEthValue(address user) public view returns(uint256 totalEthValueInUsd){
            uint256 amount = s_ethDeposited[user];
            totalEthValueInUsd += _getUsdValue(amount);
        return totalEthValueInUsd;
    }

    function getUsdValue(uint256 amount) external view returns (uint256) {
        return _getUsdValue(amount);
    }

    function getAccountInformation(address user) external view returns (uint256 totalNusdMinted, uint256 ethValueInUsd){
        (totalNusdMinted, ethValueInUsd) = _getAccountInformation(user);
    }

    function getEthBalanceOfUser() external view returns (uint256) {
        return s_ethDeposited[msg.sender];
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getNusd() external view returns (address) {
        return address(iNusd);
    }

    function getEthPriceFeed() external view returns (address) {
        return priceFeedAddress;
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

}