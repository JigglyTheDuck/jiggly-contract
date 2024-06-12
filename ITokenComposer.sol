// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenComposer {
    function passProposal(uint8 proposal, address target) external;

    function decimals() external view returns(uint8);
    
    function composeAndGetRewardContribution(
        address from,
        address to,
        uint256 value
    ) external returns(uint);
}
