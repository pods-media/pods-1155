// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";
import {PodsCreator1155Impl} from "../../../src/nft/PodsCreator1155Impl.sol";
import {Pods1155} from "../../../src/proxies/Pods1155.sol";
import {IZoraCreator1155Errors} from "../../../src/interfaces/IZoraCreator1155Errors.sol";
import {IMinter1155} from "../../../src/interfaces/IMinter1155.sol";
import {ICreatorRoyaltiesControl} from "../../../src/interfaces/ICreatorRoyaltiesControl.sol";
import {IZoraCreator1155Factory} from "../../../src/interfaces/IZoraCreator1155Factory.sol";
import {ILimitedMintPerAddressErrors} from "../../../src/interfaces/ILimitedMintPerAddress.sol";

import {IFixedPriceAllowedMintersStrategy, FixedPriceAllowedMintersStrategy} from "../../../src/minters/fixed-price/FixedPriceAllowedMintersStrategy.sol";

contract FixedPriceAllowedMintersStrategyTest is Test {
    PodsCreator1155Impl internal targetImpl;
    PodsCreator1155Impl internal target;
    FixedPriceAllowedMintersStrategy internal fixedPrice;

    address payable internal admin;
    address internal zora;
    address internal tokenRecipient;
    address internal fundsRecipient;

    address internal allowedMinter;
    address[] internal minters;

    event SaleSet(address indexed mediaContract, uint256 indexed tokenId, FixedPriceAllowedMintersStrategy.SalesConfig salesConfig);
    event MintComment(address indexed sender, address indexed tokenContract, uint256 indexed tokenId, uint256 quantity, string comment);
    event MinterSet(address indexed mediaContract, uint256 indexed tokenId, address indexed minter, bool allowed);

    function setUp() external {
        admin = payable(makeAddr("admin"));
        zora = makeAddr("zora");
        tokenRecipient = makeAddr("tokenRecipient");
        fundsRecipient = makeAddr("fundsRecipient");

        allowedMinter = makeAddr("allowedMinter");
        minters = new address[](1);
        minters[0] = allowedMinter;

        targetImpl = new PodsCreator1155Impl(zora, address(0), address(new ProtocolRewards()));
        target = PodsCreator1155Impl(payable(address(new Pods1155(address(targetImpl)))));

        target.initialize("test", "test", ICreatorRoyaltiesControl.RoyaltyConfiguration(0, 0, address(0)), admin, new bytes[](0));
        fixedPrice = new FixedPriceAllowedMintersStrategy();
    }

    function test_ContractName() external {
        assertEq(fixedPrice.contractName(), "Fixed Price Allowed Minters Strategy");
    }

    function test_Version() external {
        assertEq(fixedPrice.contractVersion(), "1.0.0");
    }

    function test_MintFromAllowedMinter() external {
        vm.startPrank(admin);

        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());

        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                FixedPriceAllowedMintersStrategy.setSale.selector,
                newTokenId,
                IFixedPriceAllowedMintersStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );

        target.callSale(newTokenId, fixedPrice, abi.encodeWithSelector(IFixedPriceAllowedMintersStrategy.setMinters.selector, newTokenId, minters, true));

        vm.stopPrank();

        uint256 numTokens = 10;
        uint256 totalReward = target.computeTotalReward(numTokens);
        uint256 totalValue = (1 ether * numTokens) + totalReward;
        vm.deal(allowedMinter, totalValue);

        vm.startPrank(allowedMinter);
        target.mintWithRewards{value: totalValue}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient, "test comment"), address(0));

        assertEq(target.balanceOf(tokenRecipient, newTokenId), 10);
        assertEq(address(target).balance, 10 ether);

        vm.stopPrank();
    }

    function test_MintFromAllowedMinterContractWide() external {
        vm.startPrank(admin);

        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        uint256 newNewTokenId = target.setupNewToken("https://zora.co/testing/token.json", 20);

        target.addPermission(0, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.addPermission(newNewTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());

        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                FixedPriceAllowedMintersStrategy.setSale.selector,
                newTokenId,
                IFixedPriceAllowedMintersStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );

        target.callSale(
            newNewTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                FixedPriceAllowedMintersStrategy.setSale.selector,
                newNewTokenId,
                IFixedPriceAllowedMintersStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );

        target.callSale(0, fixedPrice, abi.encodeWithSelector(FixedPriceAllowedMintersStrategy.setMinters.selector, 0, minters, true));

        vm.stopPrank();

        uint256 numTokens = 10;
        uint256 totalReward = target.computeTotalReward(numTokens);
        uint256 totalValue = (1 ether * numTokens) + totalReward;
        vm.deal(allowedMinter, totalValue * 2);

        vm.startPrank(allowedMinter);
        target.mintWithRewards{value: totalValue}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient, "test comment"), address(0));
        target.mintWithRewards{value: totalValue}(fixedPrice, newNewTokenId, 10, abi.encode(tokenRecipient, "test comment"), address(0));

        assertEq(target.balanceOf(tokenRecipient, newTokenId), 10);
        assertEq(target.balanceOf(tokenRecipient, newNewTokenId), 10);
        assertEq(address(target).balance, 20 ether);

        vm.stopPrank();
    }

    function testRevert_MinterNotAllowed() external {
        vm.startPrank(admin);

        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());

        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                FixedPriceAllowedMintersStrategy.setSale.selector,
                newTokenId,
                IFixedPriceAllowedMintersStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );

        target.callSale(newTokenId, fixedPrice, abi.encodeWithSelector(FixedPriceAllowedMintersStrategy.setMinters.selector, newTokenId, minters, true));

        vm.stopPrank();

        uint256 numTokens = 10;
        uint256 totalReward = target.computeTotalReward(numTokens);
        uint256 totalValue = (1 ether * numTokens) + totalReward;
        vm.deal(allowedMinter, totalValue);

        vm.expectRevert(abi.encodeWithSignature("ONLY_MINTER()"));
        target.mintWithRewards{value: totalValue}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient, "test comment"), address(0));
    }

    function test_MintersSetEvents() external {
        vm.startPrank(admin);

        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());

        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                FixedPriceAllowedMintersStrategy.setSale.selector,
                newTokenId,
                IFixedPriceAllowedMintersStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );

        vm.expectEmit(true, true, true, true);
        emit MinterSet(address(target), newTokenId, allowedMinter, true);
        target.callSale(newTokenId, fixedPrice, abi.encodeWithSelector(FixedPriceAllowedMintersStrategy.setMinters.selector, newTokenId, minters, true));

        vm.expectEmit(true, true, true, true);
        emit MinterSet(address(target), newTokenId, allowedMinter, false);
        target.callSale(newTokenId, fixedPrice, abi.encodeWithSelector(FixedPriceAllowedMintersStrategy.setMinters.selector, newTokenId, minters, false));

        vm.stopPrank();
    }
}
