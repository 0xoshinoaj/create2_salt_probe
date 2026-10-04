// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal rescue contract: move THIS contract's ETH / ERC-20 / ERC-721 / ERC-1155.
/// Owner is a constructor arg, so it is part of CREATE2 init code. Changing owner changes the address.
contract Rescue {
    address public immutable owner;

    error NotOwner();
    error ETHTransferFailed();
    error ERC20TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address owner_) {
        owner = owner_;
    }

    receive() external payable {}

    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert ETHTransferFailed();
    }

    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert ERC20TransferFailed();
    }

    function withdrawERC721(address token, address to, uint256 tokenId) external onlyOwner {
        (bool ok,) = token.call(abi.encodeWithSelector(0x23b872dd, address(this), to, tokenId));
        require(ok, "ERC721 transfer failed");
    }

    function withdrawERC1155(address token, address to, uint256 id, uint256 amount) external onlyOwner {
        (bool ok,) = token.call(
            abi.encodeWithSelector(
                0xf242432a, address(this), to, id, amount, bytes("")
            )
        );
        require(ok, "ERC1155 transfer failed");
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return 0xbc197c81;
    }
}
