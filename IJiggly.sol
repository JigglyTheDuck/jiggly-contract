// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IJiggly is IERC20 {
    function decimals() external view returns (uint8);
    function passProposal(uint8 proposal, address target) external;
}
