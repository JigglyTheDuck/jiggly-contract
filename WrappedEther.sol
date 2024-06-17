// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./WrappedToken.sol";

contract WrappedEther is WrappedToken {
    constructor() WrappedToken("WGLYETH", "GLY - ETH") {}

    receive() external payable {
        wrap(msg.value);
    }

    function _unwrap(address addr, uint256 value) internal override {
        require(isTransferAllowed(addr, value));

        _burn(addr, value);

        safeTransferETH(payable(addr), value);
    }

    function safeTransferETH(address payable recipient, uint256 value)
        internal
    {
        (bool success, ) = recipient.call{value: value}("");
        require(success, "ETH transfer failed");
    }
}
