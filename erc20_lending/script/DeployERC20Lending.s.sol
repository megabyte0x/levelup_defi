//SPDX-License-Identifier:MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

import {ERC20Lending} from "../src/ERC20Lending.sol";

contract DeployERC20Lending is Script {
    function run() public returns (address) {
        vm.startBroadcast();
        ERC20Lending lending = new ERC20Lending();
        vm.stopBroadcast();

        return address(lending);
    }
}
