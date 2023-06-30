//SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.18;

import {Script} from "forge-std/Script.sol";
import {NUSD} from "../src/NUSD.sol";
import {NUSDMain} from "../src/NUSDMain.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployNUSD is Script {
    address public priceFeedAddress;

    function run() external returns (NUSD,NUSDMain,HelperConfig){
        HelperConfig config = new HelperConfig();
        (address ethUsdPriceFeed,uint256 deployerKey) = config.activeNetworkConfig();

        priceFeedAddress = ethUsdPriceFeed;

        vm.startBroadcast(deployerKey);
        NUSD nUsd = new NUSD();
        NUSDMain nUsdMain = new NUSDMain(priceFeedAddress,address(nUsd));

        nUsd.transferOwnership(address(nUsdMain));
        vm.stopBroadcast();
        return(nUsd,nUsdMain,config);
    }
}