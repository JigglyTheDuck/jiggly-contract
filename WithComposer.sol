// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Composer.sol";

contract WithComposer {
    Composer composer;

    address pendingComposerAddress;

    constructor() {
        composer = new Composer();
        pendingComposerAddress = address(composer);
    }

    function activatePendingComposer() internal {
        if (
            pendingComposerAddress != address(composer)
        ) {
            composer = Composer(pendingComposerAddress);
        }
    }

    function changeComposer(address composerAddress) internal {
        pendingComposerAddress = composerAddress;
    }
}

