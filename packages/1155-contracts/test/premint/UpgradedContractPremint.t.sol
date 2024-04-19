// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Zora1155FactoryFixtures} from "../fixtures/Zora1155FactoryFixtures.sol";
import {Zora1155PremintFixtures} from "../fixtures/Zora1155PremintFixtures.sol";
import {ZoraCreator1155FactoryImpl} from "../../src/factory/ZoraCreator1155FactoryImpl.sol";
import {Pods1155PremintExecutor} from "../../src/proxies/Pods1155PremintExecutor.sol";
import {PodsCreator1155Impl} from "../../src/nft/PodsCreator1155Impl.sol";
import {ZoraCreator1155PremintExecutorImpl} from "../../src/delegation/ZoraCreator1155PremintExecutorImpl.sol";
import {Pods1155Factory} from "../../src/proxies/Pods1155Factory.sol";
import {IMinter1155} from "../../src/interfaces/IMinter1155.sol";
import {IZoraCreator1155} from "../../src/interfaces/IZoraCreator1155.sol";
import {ProxyShim} from "../../src/utils/ProxyShim.sol";
import {ZoraCreator1155Attribution, ContractCreationConfig, TokenCreationConfigV2, PremintConfigV2, PremintConfig} from "../../src/delegation/ZoraCreator1155Attribution.sol";
import {IOwnable2StepUpgradeable} from "../../src/utils/ownable/IOwnable2StepUpgradeable.sol";
import {IHasContractName} from "../../src/interfaces/IContractMetadata.sol";
import {ZoraCreator1155PremintExecutorImplLib} from "../../src/delegation/ZoraCreator1155PremintExecutorImplLib.sol";
import {IUpgradeGate} from "../../src/interfaces/IUpgradeGate.sol";
import {IProtocolRewards} from "@zoralabs/protocol-rewards/src/interfaces/IProtocolRewards.sol";
import {IZoraCreator1155PremintExecutor, ILegacyZoraCreator1155PremintExecutor} from "../../src/interfaces/IZoraCreator1155PremintExecutor.sol";

contract Zora1155PremintExecutorProxyTest is Test {
    function test_canExecutePremint_onOlderVersionOf1155() external {
        vm.createSelectFork("zora", 10_914_783);

        address collector = makeAddr("collector_pods");

        // create 1155 contract via premint, using legacy interface
        uint256 quantityToMint = 1;

        PodsCreator1155Impl nftContract = PodsCreator1155Impl(payable(0xCc030ab5505A1583ED416819F83Ba364C3a62e57));

        uint256 mintFeeAmount = nftContract.mintFee();

        vm.deal(collector, mintFeeAmount);
        vm.prank(collector);

        uint256 tokenId = nftContract.delegateSetupNewToken(
            hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000ffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000003e80000000000000000000000008b2e10bfd9f0c2813905a73ae2acd0468c623082000000000000000000000000169d9147dfc9409afa4e558df2c9abeebc0201820000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003061723a2f2f345347684e715f7a465643555a2d4531445f6b69653652327666716b4b4f6f454c43704d656277345f334d00000000000000000000000000000000",
            bytes32(0xad7c5bef027816a800da1736444fb58a807ef4c9603b7848673f7e3a68eb14a5),
            hex"7bca5e4e62225e239f06f60213913e1b499db3aae015174ca1296d98effdef4716785f1ff8ea0e823393267e408d311f58166544f23675b1ede6b763e89105f11b",
            collector
        );

        console.log(tokenId);
    }
}
