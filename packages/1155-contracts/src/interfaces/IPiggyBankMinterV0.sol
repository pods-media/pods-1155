// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPiggyBankMinterV0 {

    event AllocationAdded(address indexed contractAddress, uint256 indexed tokenId, uint128 costPerToken, uint32 totalAllocated, uint32 limitPerRecipient);
    event AllocationEdited(address indexed contractAddress, uint256 indexed tokenId, uint128 costPerToken, uint32 totalAllocated, uint32 limitPerRecipient);
    event AllocationPaused(address indexed contractAddress, uint256 indexed tokenId);
    event AllocationUnpaused(address indexed contractAddress, uint256 indexed tokenId);
    event PiggyBankMinted(address indexed contractAddress, uint256 indexed tokenId, uint32 quantityFree, uint128 quantityPaid, address recipient);
    event OwnerWithdraw(address indexed to, uint256 amount, address owner);

    struct Allocation {
        uint128 costPerToken;
        uint32 totalAllocated;
        uint32 totalClaimed;
        uint32 limitPerRecipient;
        bool paused;
        bool exists;
    }

    function addAllocation(
        address contractAddress,
        uint256 tokenId,
        uint32 limitPerRecipient,
        uint32 totalAllocated,
        uint128 costPerToken
    ) external;

    function editAllocation(
        address contractAddress,
        uint256 tokenId,
        uint32 limitPerRecipient,
        uint32 totalAllocated,
        uint128 costPerToken
    ) external;

    function pauseAllocation(address contractAddress, uint256 tokenId) external;
    function unpauseAllocation(address contractAddress, uint256 tokenId) external;

    function mintPiggyBank(
        address contractAddress,
        uint256 tokenId,
        uint32 quantityFree,
        uint128 quantityPaid,
        address recipient
    ) external payable;

    function claimsAvailable(
        address contractAddress,
        uint256 tokenId,
        address recipient
    ) external view returns (uint256);

    function getAllocation(
        address contractAddress,
        uint256 tokenId
    ) external view returns (Allocation memory);
}


