// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal CREATE2 factory. Address depends on how THIS factory is deployed.
/// Prefer the public deterministic deployer 0x4e59b44847b379578588920cA78FbF26c0B4956C when it exists on that chain.
contract Create2Factory {
    error DeployFailed();

    event Deployed(address indexed addr, bytes32 indexed salt);

    function deploy(bytes32 salt, bytes memory initCode) external payable returns (address addr) {
        assembly {
            addr := create2(callvalue(), add(initCode, 0x20), mload(initCode), salt)
        }
        if (addr == address(0)) revert DeployFailed();
        emit Deployed(addr, salt);
    }
}
