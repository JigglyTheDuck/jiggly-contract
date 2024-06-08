// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TimeTracker {
    uint64 segmentLength;
    uint256 lastTimestamp;

    constructor(uint64 _segmentLength) {
        lastTimestamp = block.timestamp;
        segmentLength = _segmentLength;
    }

    function changeSegmentLength(uint64 newLength) internal {
        segmentLength = newLength;
    }

    function progressTime() internal {
        lastTimestamp += segmentLength;
    }
}
