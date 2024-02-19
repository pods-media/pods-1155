// spdx-license-identifier: mit
pragma solidity ^0.8.17;

import {Pods1155Factory} from "@zoralabs/zora-1155-contracts/src/proxies/Pods1155Factory.sol";
import {PodsCreator1155Impl} from "@zoralabs/zora-1155-contracts/src/nft/PodsCreator1155Impl.sol";
import {IZoraCreator1155Factory} from "@zoralabs/zora-1155-contracts/src/interfaces/IZoraCreator1155Factory.sol";
import {ZoraCreator1155FactoryImpl} from "@zoralabs/zora-1155-contracts/src/factory/ZoraCreator1155FactoryImpl.sol";
import {IMinter1155} from "@zoralabs/zora-1155-contracts/src/interfaces/IMinter1155.sol";
import {Deployment, ChainConfig} from "./DeploymentConfig.sol";
import {ProxyShim} from "@zoralabs/zora-1155-contracts/src/utils/ProxyShim.sol";
import {ZoraCreator1155PremintExecutorImpl} from "@zoralabs/zora-1155-contracts/src/delegation/ZoraCreator1155PremintExecutorImpl.sol";
import {IImmutableCreate2Factory} from "./IImmutableCreate2Factory.sol";
import {DeterministicProxyDeployer} from "./DeterministicProxyDeployer.sol";
import {ZoraCreatorFixedPriceSaleStrategy} from "@zoralabs/zora-1155-contracts/src/minters/fixed-price/ZoraCreatorFixedPriceSaleStrategy.sol";
import {ZoraCreatorMerkleMinterStrategy} from "@zoralabs/zora-1155-contracts/src/minters/merkle/ZoraCreatorMerkleMinterStrategy.sol";
import {ZoraCreatorRedeemMinterFactory} from "@zoralabs/zora-1155-contracts/src/minters/redeem/ZoraCreatorRedeemMinterFactory.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ICreatorRoyaltiesControl} from "@zoralabs/zora-1155-contracts/src/interfaces/ICreatorRoyaltiesControl.sol";
import {UpgradeGate} from "@zoralabs/zora-1155-contracts/src/upgrades/UpgradeGate.sol";
import {UUPSUpgradeable} from "@zoralabs/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

struct Create2Deployment {
    address deployerAddress;
    bytes32 salt;
    bytes constructorArguments;
    address deployedAddress;
}

library ZoraDeployerUtils {
    IImmutableCreate2Factory constant IMMUTABLE_CREATE2_FACTORY = IImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);

    bytes32 constant IMMUTABLE_CREATE_2_FRIENDLY_SALT = bytes32(0x0000000000000000000000000000000000000000000000000000000000000001);

    function deployWithImmutableCreate2(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory constructorArguments
    ) internal returns (Create2Deployment memory) {
        address deployedAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2(salt, abi.encodePacked(creationCode, constructorArguments));

        return
            Create2Deployment({
                deployerAddress: address(IMMUTABLE_CREATE2_FACTORY),
                salt: salt,
                constructorArguments: constructorArguments,
                deployedAddress: deployedAddress
            });
    }

    function ensureValidUpgradeGate(address upgradeGateAddress) internal pure {
        require(
            keccak256(abi.encodePacked(UpgradeGate(upgradeGateAddress).contractName())) == keccak256(abi.encodePacked("ZORA 1155 Upgrade Gate")),
            "INVALID_UPGRADE_GATE"
        );
    }

    function deployNew1155AndFactoryImpl(
        address upgradeGateAddress,
        address mintFeeRecipient,
        address protocolRewards,
        IMinter1155 merkleMinter,
        IMinter1155 redeemMinterFactory,
        IMinter1155 fixedPriceMinter
    ) internal returns (address factoryImplAddress, address contract1155ImplAddress, string memory contract1155ImplVersion) {
        ensureValidUpgradeGate(upgradeGateAddress);

        PodsCreator1155Impl zoraCreator1155Impl = new PodsCreator1155Impl(mintFeeRecipient, upgradeGateAddress, protocolRewards);

        contract1155ImplVersion = zoraCreator1155Impl.contractVersion();

        contract1155ImplAddress = address(zoraCreator1155Impl);
        factoryImplAddress = address(
            new ZoraCreator1155FactoryImpl({
                _zora1155Impl: zoraCreator1155Impl,
                _merkleMinter: merkleMinter,
                _redeemMinterFactory: redeemMinterFactory,
                _fixedPriceMinter: fixedPriceMinter
            })
        );
    }

    function deployImmutableOrGetAddress(bytes32 salt, bytes memory creationCode) internal returns (address) {
        address deployedAddress = Create2.computeAddress(salt, keccak256(creationCode), address(IMMUTABLE_CREATE2_FACTORY));
        if (IMMUTABLE_CREATE2_FACTORY.hasBeenDeployed(deployedAddress)) {
            return deployedAddress;
        }

        return IMMUTABLE_CREATE2_FACTORY.safeCreate2(salt, creationCode);
    }

    function deployMinters() internal returns (address fixedPriceMinter, address merkleMinter, address redeemMinterFactory) {
        fixedPriceMinter = deployImmutableOrGetAddress(
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000001),
            type(ZoraCreatorFixedPriceSaleStrategy).creationCode
        );

        merkleMinter = deployImmutableOrGetAddress(
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000001),
            type(ZoraCreatorMerkleMinterStrategy).creationCode
        );

        redeemMinterFactory = deployImmutableOrGetAddress(
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000001),
            type(ZoraCreatorRedeemMinterFactory).creationCode
        );
    }

    // we dont care what this salt is, as long as it's the same for all deployments and it has first 20 bytes of 0
    // so that anyone can deploy it
    bytes32 constant FACTORY_DEPLOYER_DEPLOYMENT_SALT = bytes32(0x0000000000000000000000000000000000000000668d7f9ed18e35000dbaba0f);

    function createDeterministicFactoryProxyDeployer() internal returns (DeterministicProxyDeployer) {
        return
            DeterministicProxyDeployer(IMMUTABLE_CREATE2_FACTORY.safeCreate2(FACTORY_DEPLOYER_DEPLOYMENT_SALT, type(DeterministicProxyDeployer).creationCode));
    }

    function deployNewPreminterImplementationDeterminstic(address factoryProxyAddress) internal returns (address) {
        // create preminter implementation
        bytes memory creationCode = abi.encodePacked(type(ZoraCreator1155PremintExecutorImpl).creationCode, abi.encode(factoryProxyAddress));

        bytes32 salt = bytes32(0x0000000000000000000000000000000000000000668d7f9ec18e35000dbaba0e);

        address determinsticAddress = ZoraDeployerUtils.getImmutableCreate2Address(salt, creationCode);

        ZoraDeployerUtils.getOrImmutable2Create(determinsticAddress, salt, creationCode);

        return determinsticAddress;
    }

    function deterministicFactoryDeployerAddress() internal view returns (address) {
        // we can know deterministically what the address of the new factory proxy deployer will be, given it's deployed from with the salt and init code,
        // from the ImmutableCreate2Factory
        return IMMUTABLE_CREATE2_FACTORY.findCreate2Address(FACTORY_DEPLOYER_DEPLOYMENT_SALT, type(DeterministicProxyDeployer).creationCode);
    }

    function factoryProxyConstructorArguments(bytes32 proxyShimSalt, address proxyDeployerAddress) internal pure returns (bytes memory) {
        address proxyShimAddress = Create2.computeAddress(
            proxyShimSalt,
            keccak256(abi.encodePacked(type(ProxyShim).creationCode, abi.encode(proxyDeployerAddress))),
            proxyDeployerAddress
        );

        return abi.encode(proxyShimAddress, "");
    }

    function deterministicFactoryProxyAddress(bytes32 proxyShimSalt, bytes32 factoryProxySalt, address proxyDeployerAddress) internal pure returns (address) {
        bytes memory constructorArguments = factoryProxyConstructorArguments(proxyShimSalt, proxyDeployerAddress);

        return
            Create2.computeAddress(
                factoryProxySalt,
                keccak256(abi.encodePacked(type(Pods1155Factory).creationCode, constructorArguments)),
                proxyDeployerAddress
            );
    }

    error MismatchedAddress(address expected, address actual);

    function getImmutableCreate2Address(bytes32 salt, bytes memory creationCode) internal pure returns (address) {
        return Create2.computeAddress(salt, keccak256(creationCode), address(IMMUTABLE_CREATE2_FACTORY));
    }

    function getOrImmutable2Create(address expectedAddress, bytes32 salt, bytes memory creationCode) internal returns (bool contractWasCreated) {
        if (IMMUTABLE_CREATE2_FACTORY.hasBeenDeployed(expectedAddress)) {
            return false;
        } else {
            address result = ZoraDeployerUtils.IMMUTABLE_CREATE2_FACTORY.safeCreate2(salt, creationCode);

            if (result != expectedAddress) revert MismatchedAddress(expectedAddress, result);

            return true;
        }
    }

    /// @notice Deploy a test contract for etherscan auto-verification
    /// @param factoryProxy Factory address to use
    /// @param admin Admin owner address to use
    function deployTestContractForVerification(address factoryProxy, address admin) internal returns (address) {
        bytes[] memory initUpdate = new bytes[](1);
        initUpdate[0] = abi.encodeWithSelector(
            PodsCreator1155Impl.setupNewToken.selector,
            "ipfs://bafkreigu544g6wjvqcysurpzy5pcskbt45a5f33m6wgythpgb3rfqi3lzi",
            100
        );
        return
            address(
                IZoraCreator1155Factory(factoryProxy).createContract(
                    "ipfs://bafybeicgolwqpozsc7iwgytavete56a2nnytzix2nb2rxefdvbtwwtnnoe/metadata",
                    unicode"🪄",
                    ICreatorRoyaltiesControl.RoyaltyConfiguration({royaltyBPS: 0, royaltyRecipient: address(0), royaltyMintSchedule: 0}),
                    payable(admin),
                    initUpdate
                )
            );
    }

    function getUpgradeCalldata(address targetImpl) internal pure returns (bytes memory upgradeCalldata) {
        // simulate upgrade call
        upgradeCalldata = abi.encodeWithSelector(UUPSUpgradeable.upgradeTo.selector, targetImpl);
    }

    function simulateUpgrade(address targetProxy, address targetImpl) internal returns (bytes memory upgradeCalldata) {
        // console log update information

        upgradeCalldata = getUpgradeCalldata(targetImpl);

        // upgrade the factory proxy to the new implementation
        (bool success, ) = targetProxy.call(upgradeCalldata);

        require(success, "upgrade failed");
    }
}
