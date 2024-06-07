// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DAO.sol";

contract Rewards is DAO {
    struct Contribution {
        uint160 value;
        uint64 lastTimestamp;
        uint8 optionIndex;
    }

    // to incentivize agreement
    uint256 public segmentPoolSize; // public as ongoing transactions may affect actual balance
    uint256 previousContributionsVolume;
    uint previousOption;
    uint256[64] contributionVolumes;

    mapping(address => Contribution) public contributions;

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
        return Composer(composerAddress).getNextOptions();
    }

    function resetSegmentRewards(uint selectedOption) internal returns (uint256) {
        previousContributionsVolume = contributionVolumes[selectedOption];
        uint256 optionsLength = getNextOptions();

        // reset contributions
        for (uint256 i = 0; i < optionsLength; ++i) contributionVolumes[i] = 0;

        uint256 rewardPoolFeeFraction = transferRewardPoolFeeFraction / 5; // 5x the tax

        rewardPoolFeeFraction = rewardPoolFeeFraction == 0 ? 1 : rewardPoolFeeFraction;
        
        uint256 maxPoolSize = balanceOf(address(this));
        
        segmentPoolSize = previousContributionsVolume / rewardPoolFeeFraction > maxPoolSize ? maxPoolSize : previousContributionsVolume / rewardPoolFeeFraction;

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

