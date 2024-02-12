// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ZoraDeployerBase} from "./ZoraDeployerBase.sol";
import {ChainConfig, Deployment} from "../src/deployment/DeploymentConfig.sol";

import {Pods1155Factory} from "../src/proxies/Pods1155Factory.sol";
import {PodsCreator1155Impl} from "../src/nft/PodsCreator1155Impl.sol";

contract DeployScript is ZoraDeployerBase {
    function run() public {
        ChainConfig memory chainConfig = getChainConfig();

        console2.log("zoraFeeRecipient", chainConfig.mintFeeRecipient);
        console2.log("factoryOwner", chainConfig.factoryOwner);
        console2.log("protocolRewards", chainConfig.protocolRewards);

        address deployer = vm.envAddress("DEPLOYER");
        address factoryProxyAddress = vm.envAddress("FACTORY_PROXY");
        console2.log("Deployer", deployer);

        vm.startBroadcast(deployer);

        Pods1155Factory factoryProxy = Pods1155Factory(payable(factoryProxyAddress));

        PodsCreator1155Impl creatorImpl = new PodsCreator1155Impl(chainConfig.mintFeeRecipient, address(factoryProxy), chainConfig.protocolRewards);

        console2.log("creatorImpl", address(creatorImpl));
    }
}
