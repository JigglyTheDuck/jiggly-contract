// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./token/ERC20/IERC20.sol";

interface IJiggly is IERC20 {
    function passProposal(uint8 _proposal, address target) external;
}
