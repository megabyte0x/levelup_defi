//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

import {CollateralisedLending} from "../src/CollateralisedLending.sol";

contract DeployCollateralisedLending is Script {
    function run() public returns (address lending) {
        vm.startBroadcast();
        CollateralisedLending newContract = new CollateralisedLending();
        vm.stopBroadcast();

        lending = address(newContract);
    }
}
