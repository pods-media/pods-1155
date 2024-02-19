// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {ZoraDeployerBase} from "../src/ZoraDeployerBase.sol";
import {ChainConfig, Deployment} from "../src/DeploymentConfig.sol";

import {ZoraCreator1155FactoryImpl} from "@zoralabs/zora-1155-contracts/src/factory/ZoraCreator1155FactoryImpl.sol";
import {Pods1155Factory} from "@zoralabs/zora-1155-contracts/src/proxies/Pods1155Factory.sol";
import {PodsCreator1155Impl} from "@zoralabs/zora-1155-contracts/src/nft/PodsCreator1155Impl.sol";
import {ICreatorRoyaltiesControl} from "@zoralabs/zora-1155-contracts/src/interfaces/ICreatorRoyaltiesControl.sol";
import {IZoraCreator1155Factory} from "@zoralabs/zora-1155-contracts/src/interfaces/IZoraCreator1155Factory.sol";
import {IMinter1155} from "@zoralabs/zora-1155-contracts/src/interfaces/IMinter1155.sol";
import {IZoraCreator1155} from "@zoralabs/zora-1155-contracts/src/interfaces/IZoraCreator1155.sol";
import {ZoraCreatorFixedPriceSaleStrategy} from "@zoralabs/zora-1155-contracts/src/minters/fixed-price/ZoraCreatorFixedPriceSaleStrategy.sol";
import {ZoraCreatorMerkleMinterStrategy} from "@zoralabs/zora-1155-contracts/src/minters/merkle/ZoraCreatorMerkleMinterStrategy.sol";
import {ZoraCreatorRedeemMinterFactory} from "@zoralabs/zora-1155-contracts/src/minters/redeem/ZoraCreatorRedeemMinterFactory.sol";
import {ZoraDeployerUtils} from "../src/ZoraDeployerUtils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract UpgradeScript is ZoraDeployerBase {
    using Strings for uint256;
    using stdJson for string;

    string configFile;

    function run() public returns (string memory) {
        Deployment memory deployment = getDeployment();
        ChainConfig memory chainConfig = getChainConfig();

        vm.startBroadcast();

        if (deployment.fixedPriceSaleStrategy == address(0)) {
            deployment.fixedPriceSaleStrategy = address(new ZoraCreatorFixedPriceSaleStrategy());
            console2.log("New FixedPriceMinter", deployment.fixedPriceSaleStrategy);
        } else {
            console2.log("Existing FIXED_PRICE_STRATEGY", deployment.fixedPriceSaleStrategy);
        }

        if (deployment.merkleMintSaleStrategy == address(0)) {
            deployment.merkleMintSaleStrategy = address(new ZoraCreatorMerkleMinterStrategy());
            console2.log("New MerkleMintStrategy", deployment.merkleMintSaleStrategy);
        } else {
            console2.log("Existing MERKLE_MINT_STRATEGY", deployment.merkleMintSaleStrategy);
        }

        if (deployment.redeemMinterFactory == address(0)) {
            deployment.redeemMinterFactory = address(new ZoraCreatorRedeemMinterFactory());
            console2.log("New REDEEM_MINTER_FACTORY", address(deployment.redeemMinterFactory));
        } else {
            console2.log("Existing REDEEM_MINTER_FACTORY", deployment.redeemMinterFactory);
        }

        bool isNewNFTImpl = deployment.contract1155Impl == address(0);
        if (isNewNFTImpl) {
            console2.log("mintFeeRecipient", chainConfig.mintFeeRecipient);
            console2.log("protocolRewards", chainConfig.protocolRewards);
            deployment.contract1155Impl = address(new PodsCreator1155Impl(chainConfig.mintFeeRecipient, deployment.factoryProxy, chainConfig.protocolRewards));
            console2.log("New NFT_IMPL", deployment.contract1155Impl);
        } else {
            console2.log("Existing NFT_IMPL", deployment.contract1155Impl);
        }

        deployment.factoryProxy = address(
            new ZoraCreator1155FactoryImpl({
                _zora1155Impl: IZoraCreator1155(deployment.contract1155Impl),
                _merkleMinter: ZoraCreatorMerkleMinterStrategy(deployment.merkleMintSaleStrategy),
                _redeemMinterFactory: ZoraCreatorRedeemMinterFactory(deployment.redeemMinterFactory),
                _fixedPriceMinter: ZoraCreatorFixedPriceSaleStrategy(deployment.fixedPriceSaleStrategy)
            })
        );

        console2.log("New Factory Impl", deployment.factoryImpl);
        console2.log("Upgrade to this new factory impl on the proxy:", deployment.factoryProxy);

        if (isNewNFTImpl) {
            ZoraDeployerUtils.deployTestContractForVerification(deployment.factoryProxy, makeAddr("admin"));
        }

        return getDeploymentJSON(deployment);
    }
}
