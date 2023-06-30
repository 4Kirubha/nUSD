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

    modifier depositedEth(){
        vm.startPrank(USER);
        nUsdMain.depositEth{value: ETH_AMOUNT}();
        vm.stopPrank();
        _;
    }

    modifier depositedEthAndMintedNusd() {
        vm.startPrank(USER);
        nUsdMain.depositEthAndMint{value: ETH_AMOUNT};
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedEth() public depositedEthAndMintedNusd {
        uint256 userBalance = nUsd.balanceOf(USER);
        assertEq(userBalance, 10000 * PRECISION);
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

    function testCantBurnMoreThanUserHas() public {
        vm.prank(USER);
        vm.expectRevert();
        nUsdMain.burnNusd(5);
    }

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(USER);
        nUsdMain.depositEthAndMint{value: ETH_AMOUNT};
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

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        nUsdMain.depositEthAndMint{value: ETH_AMOUNT};
        vm.expectRevert(NUSDMain.NUSDMain__NeedsGreaterThanZero.selector);
        nUsdMain.redeemEth(0);
        vm.stopPrank();
    }

    function testCanRedeemEth() public depositedEthAndMintedNusd {
        vm.startPrank(USER);
        nUsdMain.redeemEth(ETH_AMOUNT);
        uint256 userBalance = address(USER).balance;
        assertEq(userBalance, ETH_AMOUNT);
        vm.stopPrank();
    }

    function testProperlyReportsHealthFactor() public depositedEthAndMintedNusd {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = nUsdMain.getHealthFactor(USER);
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedEthAndMintedNusd {
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = nUsdMain.getHealthFactor(USER);
        assert(userHealthFactor == 0.9 ether);
    }

    // function testMint() public {
    //     uint256 expected = nUsdMain.mintNusd(ETH_AMOUNT);
    //     uint256 balance = nUsd.balanceOf(USER);
    //     assertEq(expected,balance);
    // }
}