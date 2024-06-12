// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./TimeTracker.sol";
import "./WithComposer.sol";
import "./UniswapConnect.sol";

contract TokenComposer is WithComposer, TimeTracker, UniswapConnect {

    enum Proposals {
        ADJUST_DECIMALS, // 3
        NEW_COMPOSER,
        NEW_LP,
        REMOVE_LP,
        CHANGE_FEE,
        CHANGE_SEGMENT_LENGTH,
        CHANGE_MIN_SEGMENT_VOTE,
        CHANGE_ROUTER_1,
        CHANGE_ROUTER_2
    }

    struct Contribution {
        uint160 value;
        uint64 lastTimestamp;
        uint8 optionIndex;
    }

    uint8 _decimals;

    uint256[64] public optionVotes;

    uint256 public segmentVoteCount;

    // to incentivize agreement
    uint256 public segmentPoolSize; // public as ongoing transactions may affect actual balance

    uint256 previousContributionsVolume;

    uint256 previousOption; // to be able to determine whether contribution is to correct option

    uint160 minSegmentVoteCount;

    uint256[64] contributionVolumes;

    uint256 transferRewardPoolFeeFraction;

    event Segment(uint256 selectedOption);
    event Limit();

    mapping(address => Contribution) public contributions;

    address constant BETA_TOKEN = 0x0356Ee6D5c0a53f43D1AC2022B3d5bA7acf7e697; // BETA token
    address constant LIVE_TOKEN = 0x4200000000000000000000000000000000000006; // WETH

    constructor()
        TimeTracker(30 minutes)
        UniswapConnect(
            msg.sender,
            0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6, // factory
            0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24, // router 1
            0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD, // router 2
            0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f // initial hash
        )
    {
        _decimals = 9;

        minSegmentVoteCount = 10;

        initializeOptions(3000 gwei);

        addLP(BETA_TOKEN);

        transferRewardPoolFeeFraction = 200;

        emit Limit();
    }

    function decimals() external view returns (uint8) {
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

            if (isUniswapLP(getLPAddress(BETA_TOKEN))) {
                removeLP(BETA_TOKEN);
                addLP(LIVE_TOKEN);
            } 

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

    function composeAndGetRewardContribution(
        address from,
        address to,
        uint256 value
    ) external returns (uint256) {
        require(msg.sender == mainTokenAddress);
        if (isUniswapLP(to)) {
            if (isUniswap(from)) return 0; // internal tx not important
            // tokens ---> pool | sell or add liquidity

            uint256 rewards = claimRewards(from);
            if (rewards > 0) IERC20(mainTokenAddress).transfer(from, rewards);

            uint256 selectedOptionIndex = getOptionIndex(value);

            if (selectedOptionIndex != 0xff) {
                segmentVoteCount += 1;
                addContribution(from, uint8(selectedOptionIndex), value);
                optionVotes[selectedOptionIndex] += value;
            } else decreaseMaxAndRandomize(value); // no valid option selected, decreasing current MAX.
        } else decreaseMaxAndRandomize(value); // any other trade will hurt the current MAX value, and move those votes to a random one

        if (
            block.timestamp >= lastTimestamp + segmentLength &&
            segmentVoteCount >= minSegmentVoteCount
        ) proceedComposition();

        return value / transferRewardPoolFeeFraction;
    }

    function addContribution(
        address from,
        uint8 optionIndex,
        uint256 value
    ) internal {
        contributionVolumes[optionIndex] += value;

        contributions[from] = Contribution(
            uint160(value),
            uint64(lastTimestamp),
            optionIndex
        );
    }

    function getNextOptions() internal view returns (uint256) {
        return composer.getNextOptions();
    }

    function resetSegmentRewards(uint256 selectedOption)
        internal
        returns (uint256)
    {
        previousOption = selectedOption;
        previousContributionsVolume = contributionVolumes[selectedOption];

        uint256 optionsLength = getNextOptions();

        // reset contributions
        for (uint256 i = 0; i < optionsLength; ++i) contributionVolumes[i] = 0;

        uint256 rewardPoolFeeFraction = transferRewardPoolFeeFraction / 5; // 5x the tax

        uint256 maxPoolSize = IERC20(mainTokenAddress).balanceOf(address(this));

        segmentPoolSize = previousContributionsVolume / rewardPoolFeeFraction;

        if (segmentPoolSize > maxPoolSize) segmentPoolSize = maxPoolSize;

        return previousContributionsVolume;
    }

    function claimRewards(address from) internal returns (uint256) {
        if (previousContributionsVolume == 0) return 0;
        Contribution storage contribution = contributions[from];

        if (contribution.optionIndex != previousOption) return 0;
        if (contribution.lastTimestamp != lastTimestamp - segmentLength)
            return 0;

        // at this point we are sure that the previous contribution was correct

        uint256 rewards = (segmentPoolSize * contribution.value) /
            previousContributionsVolume;

        // BETA participants are rewarded 10x for all contributions
        // 5% of contribution volume
        if (isUniswapLP(getLPAddress(BETA_TOKEN))) rewards *= 10;

        // reset to avoid reentry
        contribution.value = 0;

        return rewards;
    }

    function passProposal(Proposals proposal, address target) external {
        require(msg.sender == mainTokenAddress);

        if (proposal == Proposals.NEW_LP && target != BETA_TOKEN) {
            addLP(target);
        } else if (proposal == Proposals.REMOVE_LP) {
            removeLP(target);
        } else if (proposal == Proposals.ADJUST_DECIMALS) {
            _decimals = target == address(0) && _decimals > 3
                ? _decimals - 1
                : _decimals + 1;
        } else if (proposal == Proposals.CHANGE_ROUTER_1) {
            usRouter1 = target;
        } else if (proposal == Proposals.CHANGE_ROUTER_2) {
            usRouter2 = target;
        } else if (proposal == Proposals.NEW_COMPOSER) {
            pendingComposerAddress = target;
        } else if (proposal == Proposals.CHANGE_FEE) {
            transferRewardPoolFeeFraction = target == address(1) &&
                transferRewardPoolFeeFraction > 25
                ? transferRewardPoolFeeFraction / 2
                : transferRewardPoolFeeFraction * 2;
        } else if (proposal == Proposals.CHANGE_SEGMENT_LENGTH) {
            changeSegmentLength(uint64(uint160(target)));
        } else if (proposal == Proposals.CHANGE_MIN_SEGMENT_VOTE) {
            minSegmentVoteCount = uint160(target);
        }
    }
}
