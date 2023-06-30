// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {NUSDMain} from "../../src/NUSDMain.sol";
import {NUSD} from "../../src/NUSD.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test{
    NUSD nUsd;
    NUSDMain nUsdMain;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 public timesMintCalled;
    address[] public usersWithCollateral;
    MockV3Aggregator public ethUsdPriceFeed;

    constructor (NUSD _nUsd,NUSDMain _nUsdMain) {
        nUsd = _nUsd;
        nUsdMain = _nUsdMain;
        ethUsdPriceFeed = MockV3Aggregator(nUsdMain.getEthPriceFeed());
    }

    function depositEth(uint256 amountEth) public {
        amountEth = bound(amountEth, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        vm.deal(msg.sender, amountEth);
        nUsdMain.depositEth{value: amountEth}();
        vm.stopPrank();
        usersWithCollateral.push(msg.sender);
    }

    function redeemEth(uint256 amountEth) public {
        uint256 maxCollateralToRedeem = nUsdMain.getEthBalanceOfUser();    
        amountEth = bound(amountEth, 0, maxCollateralToRedeem);
        if(amountEth == 0){
            return;
        }
        nUsdMain.redeemEth(amountEth);
    }

    function mintNusd(uint256 amount,uint256 addressSeed) public {
        if(usersWithCollateral.length == 0){
            return;
        }
        address sender = usersWithCollateral[addressSeed % usersWithCollateral.length];
        (uint256 totalNusdMinted, uint256 ethValueInUsd) = nUsdMain.getAccountInformation(sender);
        int256 maxNusdTomint = (int256(ethValueInUsd)/2) - int256(totalNusdMinted);
        if(maxNusdTomint < 0){
            return;
        }
        amount = bound(amount, 0, uint256(maxNusdTomint));
        if(amount == 0){
            return;
        }
        vm.startPrank(sender);
        nUsdMain.mintNusd(amount);
        vm.stopPrank();
        timesMintCalled++;
    }
}