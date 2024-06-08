// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TimeTracker.sol";
import "./WithComposer.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Rewards is WithComposer, TimeTracker, ERC20, ERC20Permit {
    struct Contribution {
        uint160 value;
        uint64 lastTimestamp;
        uint8 optionIndex;
    }

    // to incentivize agreement
    uint256 public segmentPoolSize; // public as ongoing transactions may affect actual balance

    uint256 previousContributionsVolume;

    uint256 previousOption;

    uint256[64] contributionVolumes;

    uint256 transferRewardPoolFeeFraction;

    mapping(address => Contribution) public contributions;

    constructor(
        string memory name,
        string memory symbol,
        uint64 initialSegmentLength,
        uint256 initialRewardPoolFeeFraction
    ) ERC20(name, symbol) ERC20Permit(name) TimeTracker(initialSegmentLength) {
        transferRewardPoolFeeFraction = initialRewardPoolFeeFraction;
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

    function getRewardsPerTx(uint256 value) internal view returns (uint256) {
        return value / transferRewardPoolFeeFraction;
    }

    function resetSegmentRewards(uint256 selectedOption)
        internal
        returns (uint256)
    {
        previousContributionsVolume = contributionVolumes[selectedOption];
        uint256 optionsLength = getNextOptions();

        // reset contributions
        for (uint256 i = 0; i < optionsLength; ++i) contributionVolumes[i] = 0;

        uint256 rewardPoolFeeFraction = transferRewardPoolFeeFraction / 5; // 5x the tax

        rewardPoolFeeFraction = rewardPoolFeeFraction == 0
            ? 1
            : rewardPoolFeeFraction;

        uint256 maxPoolSize = balanceOf(address(this));

        segmentPoolSize = previousContributionsVolume / rewardPoolFeeFraction >
            maxPoolSize
            ? maxPoolSize
            : previousContributionsVolume / rewardPoolFeeFraction;

        previousOption = selectedOption;

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

        // reset to avoid reentry
        contribution.value = 0;

        return rewards;
    }
}
