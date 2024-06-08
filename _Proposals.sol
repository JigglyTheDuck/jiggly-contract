// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library _Proposals {
    enum Proposals {
        EMPTY,
        NEW_COMPOSER,
        NEW_LP,
        REMOVE_LP,
        CHANGE_FEE,
        CHANGE_SEGMENT_LENGTH,
        CHANGE_MIN_SEGMENT_VOTE,
        ADJUST_DECIMALS,
        CHANGE_ROUTER,
        CHANGE_DAO
    }
}

