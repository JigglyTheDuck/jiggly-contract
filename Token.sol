// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Composer.sol";
import "./Rewards.sol";
import "./Approver.sol";
import "./UniswapConnect.sol";
import "./DAO.sol";

contract Jiggly is Rewards, UniswapConnect {
    uint256[64] public optionVotes;
    uint16 public segmentVoteCount = 0;

    address dao;

    uint16 minSegmentVoteCount;

    uint8 _decimals;

    event Segment(uint256 selectedOption);
    event Limit();

    constructor()
        Rewards("Jiggly", "GLY", 30 minutes, 200)
        UniswapConnect(
            0x9e5A52f57b3038F1B8EeE45F28b3C1967e22799C,
            0xedf6066a2b290C185783862C7F4776A2C8077AD1,
            0xec7BE89e9d109e7e3Fec59c222CF297125FEFda2,
            0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f
        )
    {
        _decimals = 9; // initially using gwei units for simplicity

        minSegmentVoteCount = 1;

        addLP(0xe53bF56F8E5BfC508A08cD2C375c0257044114F7);

        dao = address(new DAO());

        initializeOptions(1000 gwei);

        _mint(address(this), 250000 gwei);

        _mint(msg.sender, 250000 gwei - 1);

        // for discoverability.
        _mint(dao, 1);

        //_mint(address(this), 500000 gwei); eventual claimable rewards, a smart contract with a single redeem function
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

        if (composer.applyOption(maxIndex)) {
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

    function passProposal(_Proposals.Proposals proposal, address target) external {
        require(msg.sender == dao);

        if (proposal == _Proposals.Proposals.NEW_LP) {
            addLP(target);
        } else if (proposal == _Proposals.Proposals.REMOVE_LP) {
            removeLP(target);
        } else if (proposal == _Proposals.Proposals.CHANGE_ROUTER) {
            usRouter1 = target;
        } else if (proposal == _Proposals.Proposals.CHANGE_DAO) {
            dao = target;
        } else if (proposal == _Proposals.Proposals.NEW_COMPOSER) {
            pendingComposerAddress = target;
        } else if (proposal == _Proposals.Proposals.CHANGE_FEE) {
            transferRewardPoolFeeFraction = target == address(1) && transferRewardPoolFeeFraction > 25
                ? transferRewardPoolFeeFraction / 2
                : transferRewardPoolFeeFraction * 2;
        } else if (proposal == _Proposals.Proposals.ADJUST_DECIMALS) {
            _decimals = target == address(1) && _decimals > 3
                ? _decimals - 1
                : _decimals + 1;
        } else if (proposal == _Proposals.Proposals.CHANGE_SEGMENT_LENGTH) {
            changeSegmentLength(uint64(uint160(target)));
        } else if (proposal == _Proposals.Proposals.CHANGE_MIN_SEGMENT_VOTE) {
            minSegmentVoteCount = uint16(uint160(target));
        }
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
    function transferFrom2(
        address from,
        address to,
        uint256 value
    ) public returns (bool) {
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
    function transfer2(address to, uint256 value) public returns (bool) {
        address owner = _msgSender();
        composeAndTransfer(owner, to, value);
        return true;
    }
}
