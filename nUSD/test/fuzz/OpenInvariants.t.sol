// //SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployNUSD} from "../../script/DeployNUSD.s.sol";
// import {NUSDMain} from "../../src/NUSDMain.sol";
// import {NUSD} from "../../src/NUSD.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";

// contract OpenInvariantsTest is StdInvariant,Test{
//     DeployNUSD deployer;
//     NUSD nUsd;
//     NUSDMain nUsdMain;
//     HelperConfig config;
//     address ethUsdPriceFeed;

//     function setUp() external {
//         deployer = new DeployNUSD();
//         (nUsd,nUsdMain,config) = deployer.run();
//         (ethUsdPriceFeed,) = config.activeNetworkConfig();
//         targetContract(address(nUsdMain));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         uint256 totalSupply = nUsd.totalSupply();
//         uint256 totalEthDeposited = address(nUsdMain).balance;
//         uint256 ethValue = nUsdMain.getUsdValue(totalEthDeposited);
//         assert(ethValue >= totalSupply);
//     }
// }