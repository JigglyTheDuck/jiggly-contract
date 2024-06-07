// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Composer.sol";
import "./Rewards.sol";

contract Jiggly is Rewards {
    uint256[64] public optionVotes;
    uint16 public segmentVoteCount = 0;

    event Segment(uint256 selectedOption);
    event Limit();

    constructor() Rewards() {
        initializeOptions(1000 gwei);

        emit Limit();
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function getOptionIndex(uint256 value) internal view returns (uint256) {
        uint256 MOD = 10**_decimals;
        uint256 decimalValue = value % MOD;
        uint256 insignifcant = MOD / 1000 - 1;

        if (decimalValue < insignifcant) return 0xff;

        uint256 selectedOption = (decimalValue - insignifcant) / (MOD / 100);

        if (selectedOption >= getNextOptions()) return 0xff;

        return selectedOption;
    }

    function initializeOptions(uint256 previousContributionVolume) internal {
        bytes32 r = blockhash(block.number - 1);
        uint256 optionsLength = getNextOptions();

        for (uint256 i = 0; i < optionsLength; ++i) {
            optionVotes[i] = (uint8(r[i]) * previousContributionVolume) / 0xff;
        }
    }

    function getMaxOption() internal view returns (uint256) {
        uint256 maxValue = 0;
        uint256 maxIndex = 0;
        uint256 optionsLength = getNextOptions();

        for (uint256 i = 0; i < optionsLength; ++i) {
            if (optionVotes[i] > maxValue) {
                maxValue = optionVotes[i];
                maxIndex = i;
            }
        }

        return maxIndex;
    }

    function proceedComposition() internal {
        uint256 maxIndex = getMaxOption();

        emit Segment(maxIndex);

        if (Composer(composerAddress).applyOption(maxIndex)) {
            emit Limit();

            activatePendingComposer();
        }

        segmentVoteCount = 0;

        progressTime();

        initializeOptions(resetSegmentRewards(maxIndex));
    }

    function decreaseMaxAndRandomize(uint256 value) internal {
        uint256 maxIndex = getMaxOption();
        uint256 votesToMove = optionVotes[maxIndex] > value
            ? value
            : optionVotes[maxIndex];
        optionVotes[maxIndex] -= votesToMove;
        optionVotes[
            uint8(blockhash(block.number - 1)[0]) % getNextOptions()
        ] += votesToMove;
    }

    function composeAndTransfer(
        address from,
        address to,
        uint256 value
    ) internal {
        if (isUniswapLP(to)) {
            // tokens ---> pool | sell or add liquidity

            uint256 rewards = claimRewards(from);
            if (rewards > 0) _transfer(address(this), from, rewards);

            uint256 selectedOptionIndex = getOptionIndex(value);

            if (selectedOptionIndex != 0xff) {
                segmentVoteCount += 1;
                addContribution(from, uint8(selectedOptionIndex), value);
                optionVotes[selectedOptionIndex] += value;
            } else decreaseMaxAndRandomize(value); // no valid option selected, decreasing current MAX.
        } else decreaseMaxAndRandomize(value); // any other trade will hurt the current MAX value, and move those votes to a random one

        if (
            block.timestamp > lastTimestamp + segmentLength &&
            segmentVoteCount >= minSegmentVoteCount
        ) proceedComposition();

        uint256 toRewardPool = isUniswap(from) && isUniswap(to)
            ? 0 // don't tax internal transactions
            : getRewardsPerTx(value);

        _transfer(from, to, value - toRewardPool);

        if (toRewardPool > 0)
            _transfer(isUniswap(from) ? to : from, address(this), toRewardPool);
    }

    // -- ERC 20 function overrides --

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        composeAndTransfer(from, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value)
        public
        override
        returns (bool)
    {
        address owner = _msgSender();
        composeAndTransfer(owner, to, value);
        return true;
    }
}

