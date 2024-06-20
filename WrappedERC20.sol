// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./WrappedToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WrappedERC20 is WrappedToken {
    address mainTokenAddress;

    constructor(address tokenAddress)
        WrappedToken("WGLYBETA", "Wrapped GLYBETA")
    {
        mainTokenAddress = tokenAddress;
        tokenComposerAddress = msg.sender;
    }

    function _wrap(address addr, uint256 value) internal override {
        // send tokens from contract (must be pre-approved)
        IERC20(mainTokenAddress).transferFrom(addr, address(this), value);

        _mint(addr, value);
    }

    function _unwrap(address addr, uint256 value) internal override {
        require(isTransferAllowed(addr, value));

        _burn(addr, value);

        IERC20(mainTokenAddress).transfer(addr, value);
    }
}

