//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

import {DeFiLending} from "../src/DeFiLending.sol";

contract DeployDeFiLending is Script {
    function run() public returns (address) {
        vm.startBroadcast();
        DeFiLending defiLending = new DeFiLending();
        vm.stopBroadcast();

        return address(defiLending);
    }
}
