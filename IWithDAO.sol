// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_Proposals.sol";

interface IWithDAO {
    function passProposal(_Proposals.Proposals proposal, address target) external;
}
