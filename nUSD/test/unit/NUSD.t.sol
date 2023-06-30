// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {NUSD} from "../../src/NUSD.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract NUSDTest is StdCheats, Test {
    NUSD nUsd;

    function setUp() public {
        nUsd = new NUSD();
    }

    function testMustMintMoreThanZero() public {
        vm.prank(nUsd.owner());
        vm.expectRevert(NUSD.NUSD__MustBeGreaterThanZero.selector);
        nUsd.mint(address(this), 0);
    }

    function testMustBurnMoreThanZero() public {
        vm.startPrank(nUsd.owner());
        nUsd.mint(address(this), 100);
        vm.expectRevert(NUSD.NUSD__MustBeGreaterThanZero.selector);
        nUsd.burn(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanYouHave() public {
        vm.startPrank(nUsd.owner());
        nUsd.mint(address(this),100);
        vm.expectRevert(NUSD.NUSD__BurnAmountExceedsBalance.selector);
        nUsd.burn(101);
        vm.stopPrank();
    }

    function testCantMintToZeroAddress() public {
        vm.startPrank(nUsd.owner());
        vm.expectRevert(NUSD.NUSD__NotZeroAddress.selector);
        nUsd.mint(address(0), 100);
        vm.stopPrank();
    }
}