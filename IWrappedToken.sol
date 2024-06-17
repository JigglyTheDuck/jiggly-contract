// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWrappedToken {
    function lockTokens(
        address addr,
        uint160 value,
        uint64 unlocksAt
    ) external;
}
