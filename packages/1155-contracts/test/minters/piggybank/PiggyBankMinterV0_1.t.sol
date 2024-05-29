// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PiggyBankMinterV0_1} from "../../../src/minters/piggybank/PiggyBankMinterV0_1.sol";
import {IZoraCreator1155} from "../../../src/interfaces/IZoraCreator1155.sol";
import {IPiggyBankMinterV0} from "../../../src/interfaces/IPiggyBankMinterV0.sol";

import "forge-std/console.sol";
import "forge-std/Test.sol";

contract PiggyBankMinterV0Test is Test {
    PiggyBankMinterV0_1 piggyBank;
    address payable user = payable(makeAddr("user"));
    address payable owner = payable(0x1C0e93f01b65fbC938b67A96f1c26Bc27fD356A9);
    address fixedPriceMinter = 0x3678862f04290E565cCA2EF163BAeb92Bb76790C;
    address podscast = 0x36Cb061F9655368eBAe79127c0e8bD34fD5A89C2;
    address unchained = 0x9ED95F38d5D710053442141C5470dd8e3A3FC8C6;
    uint256 tokenId = 29;
    uint32 limitPerRecipient = 100;
    uint32 totalAllocated = 1;
    uint128 costPerToken = 0.0007 ether;

    IPiggyBankMinterV0.Allocation allocation =
        IPiggyBankMinterV0.Allocation(
            .0007 ether, // costPerToken
            100, // totalAllocated
            0, // totalClaimed
            1, // limitPerRecipient
            false, // paused
            true // exists
        );

    function setUp() external {
        vm.createSelectFork("optimism", 119_154_290);
        piggyBank = new PiggyBankMinterV0_1(owner, fixedPriceMinter);
        vm.deal(owner, 1 ether);
        vm.prank(owner);
        (bool success, ) = address(piggyBank).call{value: 1 ether}("");
        require(success, "ETH transfer failed.");
    }

    function makeTokenAllocation() internal {
        vm.prank(owner);
        piggyBank.addAllocation(unchained, tokenId, totalAllocated, limitPerRecipient, costPerToken);
    }

    function addAllocation() internal {
        vm.prank(owner);
        piggyBank.addAllocation(unchained, tokenId, totalAllocated, limitPerRecipient, costPerToken);
    }

    function test_canAddAllocation() external {
        makeTokenAllocation();

        IPiggyBankMinterV0.Allocation memory newAllocation = piggyBank.getAllocation(unchained, 29);
        IPiggyBankMinterV0.Allocation memory expectedAllocation = allocation;

        assertEq(newAllocation.costPerToken, expectedAllocation.costPerToken, "costPerToken incorrect");
        assertEq(newAllocation.totalAllocated, expectedAllocation.totalAllocated, "totalAllocated incorrect");
        assertEq(newAllocation.totalClaimed, expectedAllocation.totalClaimed, "totalClaimed incorrect");
        assertEq(newAllocation.limitPerRecipient, expectedAllocation.limitPerRecipient, "limitPerRecipient incorrect");
        assertEq(newAllocation.paused, expectedAllocation.paused, "allocation should not be paused");
        assertEq(newAllocation.exists, expectedAllocation.exists, "allocation should exist");
    }

    function test_canMintPiggyBank() external {
        makeTokenAllocation();

        vm.deal(user, 1 ether);

        uint256 initialPiggyBalance = address(piggyBank).balance;
        uint256 userInitialTokenBalance = IZoraCreator1155(unchained).balanceOf(user, 1);
        console.log("userInitialTokenBalance:", userInitialTokenBalance);

        vm.startPrank(user);

        assertEq(piggyBank.claimsAvailable(unchained, 29, user), 1, "there should be 1 claim available");

        // mint with 0 free
        piggyBank.mintPiggyBank{value: costPerToken}(unchained, 29, 0, 1, user);

        // minting with 0 free shouldn't impact the allocation
        assertEq(piggyBank.claimsAvailable(unchained, 29, user), 1, "allocation should not be impacted");

        // it also shouldn't change the piggy bank balance
        assertEq(initialPiggyBalance, address(piggyBank).balance, "piggy bank balance should not change");
        assertEq(IZoraCreator1155(unchained).balanceOf(user, 29), userInitialTokenBalance + 1, "user should have 1 more token");

        // mint with 1 free
        piggyBank.mintPiggyBank{value: 0 ether}(unchained, 29, 1, 0, user);

        // minting with 1 free should decrement the user's allocation
        assertEq(piggyBank.claimsAvailable(unchained, 29, user), 0, "user should have 0 claims available");

        // it should also decrement the piggy bank balance
        assertEq(initialPiggyBalance - costPerToken, address(piggyBank).balance, "piggy bank balance should decrement by costPerToken");
        assertEq(IZoraCreator1155(unchained).balanceOf(user, 29), userInitialTokenBalance + 2, "user should have 2 tokens");

        vm.expectRevert("Recipient will exceed their limit");
        piggyBank.mintPiggyBank{value: 0 ether}(unchained, 29, 1, 0, user);

        vm.stopPrank();
    }

    function test_canMintPiggyBankFallbackToContract() external {
        vm.prank(owner);

        // add allocation to contract level by setting tokenId to 0
        piggyBank.addAllocation(unchained, 0, totalAllocated, limitPerRecipient, costPerToken);

        vm.deal(user, 1 ether);

        uint256 initialPiggyBalance = address(piggyBank).balance;
        uint256 userInitialTokenBalance = IZoraCreator1155(unchained).balanceOf(user, 1);

        vm.startPrank(user);

        assertEq(piggyBank.claimsAvailable(unchained, 29, user), 1, "there should be 1 claim available");

        // mint with 0 free
        piggyBank.mintPiggyBank{value: costPerToken}(unchained, 29, 0, 1, user);

        // minting with 0 free shouldn't impact the allocation
        assertEq(piggyBank.claimsAvailable(unchained, 29, user), 1, "allocation should not be impacted");

        // it also shouldn't change the piggy bank balance
        assertEq(initialPiggyBalance, address(piggyBank).balance, "piggy bank balance should not change");
        assertEq(IZoraCreator1155(unchained).balanceOf(user, 29), userInitialTokenBalance + 1, "user should have 1 more token");

        // mint with 1 free
        piggyBank.mintPiggyBank{value: 0 ether}(unchained, 29, 1, 0, user);

        // minting with 1 free should decrement the user's allocation
        assertEq(piggyBank.claimsAvailable(unchained, 29, user), 0, "user should have 0 claims available");

        // it should also decrement the piggy bank balance
        assertEq(initialPiggyBalance - costPerToken, address(piggyBank).balance, "piggy bank balance should decrement by costPerToken");
        assertEq(IZoraCreator1155(unchained).balanceOf(user, 29), userInitialTokenBalance + 2, "user should have 2 tokens");

        vm.expectRevert("Recipient will exceed their limit");
        piggyBank.mintPiggyBank{value: 0 ether}(unchained, 29, 1, 0, user);

        vm.stopPrank();
    }
}
