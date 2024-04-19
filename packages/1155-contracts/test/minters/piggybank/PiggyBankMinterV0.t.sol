// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PiggyBankMinterV0} from "../../../src/minters/piggybank/PiggyBankMinterV0.sol";
import {IZoraCreator1155} from "../../../src/interfaces/IZoraCreator1155.sol";

import "forge-std/Test.sol";

contract PiggyBankMinterV0Test is Test {
    PiggyBankMinterV0 piggyBank;
    address payable owner = payable(0x1C0e93f01b65fbC938b67A96f1c26Bc27fD356A9);
    address fixedPriceMinter = 0x04E2516A2c207E84a1839755675dfd8eF6302F0a;
    address podscast = 0x36Cb061F9655368eBAe79127c0e8bD34fD5A89C2;

    function setUp() external {
        vm.createSelectFork("base", 13_385_734);
        piggyBank = new PiggyBankMinterV0(owner, fixedPriceMinter);
        vm.deal(owner, 1 ether);
        vm.prank(owner);
        (bool success, ) = address(piggyBank).call{value: 1 ether}("");
        require(success, "ETH transfer failed.");
    }

    function makeAllocation() internal {
        vm.prank(owner);
        piggyBank.addAllocation(podscast, 1, 1, 100, .0007 ether);
    }

    function test_canAddAllocation() external {
        makeAllocation();
    }

    function test_canMintPiggyBank() external {
        makeAllocation();

        address payable user = payable(makeAddr("user"));
        vm.deal(user, 1 ether);

        uint256 initialPiggyBalance = address(piggyBank).balance;
        uint256 userInitialTokenBalance = IZoraCreator1155(podscast).balanceOf(user, 1);

        vm.startPrank(user);
        assertEq(piggyBank.claimsAvailable(podscast, 1, user), 1);
        piggyBank.mintPiggyBank{value: 0.0007 ether}(podscast, 1, 0, 1, user);
        // minting with 0 free shouldn't impact the allocation
        assertEq(piggyBank.claimsAvailable(podscast, 1, user), 1);
        // it also shouldn't change the piggy bank balance
        assertEq(initialPiggyBalance, address(piggyBank).balance);
        assertEq(IZoraCreator1155(podscast).balanceOf(user, 1), userInitialTokenBalance + 1);

        piggyBank.mintPiggyBank{value: 0.0007 ether}(podscast, 1, 1, 1, user);
        // minting with 1 free should decrement the user's allocation
        assertEq(piggyBank.claimsAvailable(podscast, 1, user), 0);
        // it should also decrement the piggy bank balance
        assertEq(initialPiggyBalance - 0.0007 ether, address(piggyBank).balance);
        assertEq(IZoraCreator1155(podscast).balanceOf(user, 1), userInitialTokenBalance + 3);

        vm.expectRevert("Recipient will exceed their limit");
        piggyBank.mintPiggyBank{value: 0 ether}(podscast, 1, 1, 0, user);
    }
}