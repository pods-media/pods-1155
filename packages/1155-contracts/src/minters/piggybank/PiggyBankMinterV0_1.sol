// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IPiggyBankMinterV0} from "../../interfaces/IPiggyBankMinterV0.sol";
import {IZoraCreator1155} from "../../interfaces/IZoraCreator1155.sol";
import {IMinter1155} from "../../interfaces/IMinter1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract PiggyBankMinterV0_1 is IPiggyBankMinterV0, Ownable, Initializable {
    IMinter1155 public fixedPriceMinter;

    /// @dev 1155 contract -> 1155 tokenId -> allocation
    mapping (address => mapping(uint256 => Allocation)) internal allocations;
    /// @dev 1155 contract -> 1155 tokenId -> recipient -> claimed
    mapping (address => mapping(uint256 => mapping(address => uint32))) internal claims;

    constructor(address _owner, address _fixedPriceMinter) {
        initialize(_owner, _fixedPriceMinter);
    }

    function initialize(address _owner, address _fixedPriceMinter) public initializer {
        _transferOwnership(_owner);
        fixedPriceMinter = IMinter1155(_fixedPriceMinter);
    }

    function ownerWithdraw(address to, uint256 amount) public onlyOwner {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "ETH transfer failed.");
    }

    function sweep(address to) external onlyOwner {
        ownerWithdraw(to, address(this).balance);
    }

    function addAllocation(
        address contractAddress,
        uint256 tokenId,
        uint32 limitPerRecipient,
        uint32 totalAllocated,
        uint128 costPerToken
    ) external override onlyOwner {
        require(!allocations[contractAddress][tokenId].exists, "Allocation already exists");

        allocations[contractAddress][tokenId] = Allocation({
            costPerToken: costPerToken,
            totalAllocated: totalAllocated,
            totalClaimed: 0,
            limitPerRecipient: limitPerRecipient,
            paused: false,
            exists: true
        });

        emit AllocationAdded(contractAddress, tokenId, costPerToken, totalAllocated, limitPerRecipient);
    }

    function editAllocation(
        address contractAddress,
        uint256 tokenId,
        uint32 limitPerRecipient,
        uint32 totalAllocated,
        uint128 costPerToken
    ) external override onlyOwner {
        Allocation storage allocation = allocations[contractAddress][tokenId];
        require(allocation.exists, "Allocation does not exist");

        allocation.costPerToken = costPerToken;
        allocation.totalAllocated = totalAllocated;
        allocation.limitPerRecipient = limitPerRecipient;

        emit AllocationEdited(contractAddress, tokenId, costPerToken, totalAllocated, limitPerRecipient);
    }

    function pauseAllocation(address contractAddress, uint256 tokenId) external override onlyOwner {
        Allocation storage allocation = allocations[contractAddress][tokenId];
        require(allocation.exists, "Allocation does not exist");

        allocation.paused = true;
    }

    function unpauseAllocation(address contractAddress, uint256 tokenId) external override onlyOwner {
        Allocation storage allocation = allocations[contractAddress][tokenId];
        require(allocation.exists, "Allocation does not exist");

        allocation.paused = false;
    }

    function mintPiggyBank(
        address contractAddress,
        uint256 tokenId,
        uint32 quantityFree,
        uint32 quantityPaid,
        address recipient
    ) external payable {
        Allocation storage allocation;
        uint256 tokenIdForMappings = tokenId;
        if(allocations[contractAddress][tokenId].exists) {
            allocation = allocations[contractAddress][tokenId];
        } else {
            // fallback to the contract-level allocation
            allocation = allocations[contractAddress][0];
            tokenIdForMappings = 0;
        }   
        require(allocation.exists, "Allocation does not exist");
        require(!allocation.paused, "Allocation is paused");

        uint256 freeMintCost = allocation.costPerToken * quantityFree;

        require(msg.value == allocation.costPerToken * quantityPaid, "Incorrect payment amount");
        require(address(this).balance >= freeMintCost, "Insufficient contract balance");

        uint32 recipientClaimed = claims[contractAddress][tokenIdForMappings][recipient];

        require(allocation.limitPerRecipient >= quantityFree + recipientClaimed, "Recipient will exceed their limit");
        require(allocation.totalAllocated >= quantityFree + allocation.totalClaimed, "Not enough tokens allocated");

        claims[contractAddress][tokenIdForMappings][recipient] += quantityFree;
        allocation.totalClaimed += quantityFree;
        
        IZoraCreator1155(contractAddress).mintWithRewards{
            value: msg.value + freeMintCost
        }(
            fixedPriceMinter, 
            tokenId, 
            quantityFree + quantityPaid, 
            abi.encode(recipient), 
            owner()
        );
    }

    function claimsAvailable(
        address contractAddress,
        uint256 tokenId,
        address recipient
    ) external view override returns (uint256) {
        Allocation storage allocation;
        uint256 tokenIdForMappings = tokenId;
        if(allocations[contractAddress][tokenId].exists) {
            allocation = allocations[contractAddress][tokenId];
        } else {
            // fallback to the contract-level allocation
            allocation = allocations[contractAddress][0];
            tokenIdForMappings = 0;
        }   
        if(allocation.paused) return 0;

        uint128 claimed = claims[contractAddress][tokenIdForMappings][recipient];
        if(allocation.limitPerRecipient <= claimed) return 0;

        return allocation.limitPerRecipient - claimed;
    }

    function getAllocation(
        address contractAddress,
        uint256 tokenId
    ) external view override returns (Allocation memory) {
        return allocations[contractAddress][tokenId];
    }

    receive() external payable {}
}