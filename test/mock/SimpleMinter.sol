// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IMinter1155} from "../../src/interfaces/IMinter1155.sol";
import {ZoraCreator1155Impl} from "../../src/nft/ZoraCreator1155Impl.sol";

contract SimpleMinter is IMinter1155 {
    bool receiveETH;

    function setReceiveETH(bool _receiveETH) external {
        receiveETH = _receiveETH;
    }

    function requestMint(address sender, uint256 tokenId, uint256 quantity, uint256, bytes calldata minterArguments) external {
        address recipient = abi.decode(minterArguments, (address));
        ZoraCreator1155Impl(sender).adminMint(recipient, tokenId, quantity, minterArguments);
    }

    receive() external payable {
        require(receiveETH, "SimpleMinter: not accepting ETH");
    }
}
