// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {NUSD} from "../../src/NUSD.sol";
import {NUSDMain} from "../../src/NUSDMain.sol";
import {DeployNUSD} from "../../script/DeployNUSD.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract NUSDMainTest is Test{
    DeployNUSD deployer;
    NUSD nUsd;
    NUSDMain nUsdMain;
    HelperConfig config;
    address ethUsdPriceFeed;
    address public USER = makeAddr("user");
    uint256 public ETH_AMOUNT = 10 ether;
    uint256 PRECISION = 1e18;
    uint256 public STARTING_ETH_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployNUSD();
        (nUsd,nUsdMain,config) = deployer.run();
        (ethUsdPriceFeed,) = config.activeNetworkConfig();
        vm.deal(USER, STARTING_ETH_BALANCE);
    }

    //PRICE TESTS

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e8;
        uint256 actualUsd = nUsdMain.getUsdValue(ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetEthAmountFromUsd() public {
        uint256 usdAmount = 100e18;
        uint256 expectedEth = 0.05 ether;
        uint256 actualEth = nUsdMain.getEthAmountFromUsd(usdAmount);
        assertEq(expectedEth, actualEth);
    }

    //DEPOSIT ETH TESTS

    modifier depositedEth(){
        vm.startPrank(USER);
        nUsdMain.depositEth{value: ETH_AMOUNT}();
        vm.stopPrank();
        _;
    }

    function testCanDepositEthWithoutMinting() public depositedEth {
        uint256 userBalance = nUsd.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    function testRevertIfEthZero() public {
        vm.startPrank(USER);        
        vm.expectRevert(NUSDMain.NUSDMain__NeedsGreaterThanZero.selector);
        nUsdMain.depositEth();
        vm.stopPrank();
    }

    function testCanDepositEthAndGetAccountInfo() public depositedEth{
        (uint256 totalNusdMinted,uint256 ethValueInUsd) = nUsdMain.getAccountInformation(USER);
        uint256 expextedTotalNusdMinted = 0;
        uint256 expectedDepositAmount = nUsdMain.getEthAmountFromUsd(ethValueInUsd * 1e10);
        assertEq(totalNusdMinted,expextedTotalNusdMinted);
        assertEq(ETH_AMOUNT,expectedDepositAmount);
    }

    //DEPOSIT ETH AND MINT NUSD

    modifier depositedEthAndMintedNusd() {
        vm.startPrank(USER);
        nUsdMain.depositEthAndMint{value: ETH_AMOUNT}();
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedEth() public depositedEthAndMintedNusd {
        uint256 userBalance = nUsd.balanceOf(USER);
        assertEq(userBalance, 10000e18);
    }

    //MINT TESTS

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(USER);
        nUsdMain.depositEthAndMint{value: ETH_AMOUNT}();
        vm.expectRevert(NUSDMain.NUSDMain__NeedsGreaterThanZero.selector);
        nUsdMain.mintNusd(0);
        vm.stopPrank();
    }

    function testCanMintNusd() public depositedEth {
        vm.prank(USER);
        nUsdMain.mintNusd(ETH_AMOUNT);
        uint256 userBalance = nUsd.balanceOf(USER);
        assertEq(userBalance, ETH_AMOUNT);
    }

    //BURN TESTS

    function testCantBurnMoreThanUserHas() public {
        vm.prank(USER);
        vm.expectRevert();
        nUsdMain.burnNusd(5);
    }

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(USER);
        nUsdMain.depositEthAndMint{value: ETH_AMOUNT}();
        vm.expectRevert(NUSDMain.NUSDMain__NeedsGreaterThanZero.selector);
        nUsdMain.burnNusd(0);
        vm.stopPrank();
    }

    function testCanBurnNusd() public depositedEthAndMintedNusd {
        vm.startPrank(USER);
        nUsd.approve(address(nUsdMain), 10000 * PRECISION);
        nUsdMain.burnNusd(10000 * PRECISION);
        vm.stopPrank();
        uint256 userBalance = nUsd.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    //REDEEM TESTS

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        nUsdMain.depositEthAndMint{value: ETH_AMOUNT};
        vm.expectRevert(NUSDMain.NUSDMain__NeedsGreaterThanZero.selector);
        nUsdMain.redeemEth(0);
        vm.stopPrank();
    }

    function testCanRedeemEth() public depositedEth {
        vm.startPrank(USER);
        nUsdMain.redeemEth(ETH_AMOUNT);
        uint256 userBalance = address(USER).balance;
        assertEq(userBalance, ETH_AMOUNT);
        vm.stopPrank();
    }

    function testCanRedeemDepositedEth() public depositedEthAndMintedNusd {
        vm.startPrank(USER);
        nUsd.approve(address(nUsdMain), 10000e18);
        nUsdMain.redeemEthForNusd(10000);
        vm.stopPrank();

        uint256 userBalance = nUsd.balanceOf(USER);
        uint256 balance = address(USER).balance;
        console.log(balance);
        assertEq(userBalance, 0);
    }

    //HEALTH FACTOR TESTS

    function testProperlyReportsHealthFactor() public depositedEthAndMintedNusd {
        uint256 expectedHealthFactor = 1 ether;
        uint256 healthFactor = nUsdMain.getHealthFactor(USER);
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedEthAndMintedNusd {
        int256 ethUsdUpdatedPrice = 1000e8; // 1 ETH = $1000
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = nUsdMain.getHealthFactor(USER);
        assert(userHealthFactor == 0.5 ether);
    }

}