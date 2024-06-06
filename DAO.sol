// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Composer.sol";
import "./UniswapConnect.sol";
import "./TimeTracker.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract DAO is UniswapConnect, TimeTracker, ERC20, ERC20Permit {
    uint256 constant THRESHOLD_FRACTION = 15; // 1 / 15th of total supply is required for a proposal to pass

    struct Voter {
        address target;
        uint64 timestamp;
        uint256 lockedAmount;
    }

    enum Proposals {
        EMPTY,
        NEW_COMPOSER,
        NEW_LP,
        REMOVE_LP,
        CHANGE_FEE,
        CHANGE_SEGMENT_LENGTH,
        CHANGE_MIN_SEGMENT_VOTE,
        ADJUST_DECIMALS
    }

    struct Proposal {
        Proposals proposal;
        uint256 voteCount;
    }

    mapping(address => Proposal) public proposals;
    mapping(address => Voter) votes;

    uint16 minSegmentVoteCount;
    address pendingComposerAddress;
    address composerAddress;
    uint8 _decimals;
    uint256 transferRewardPoolFeeFraction;

    event ProposalPassed(Proposals proposal, address target);

    constructor()
        ERC20("Jiggly", "GLY")
        ERC20Permit("Jiggly")
        TimeTracker(30 minutes)
        UniswapConnect(
            0x9e5A52f57b3038F1B8EeE45F28b3C1967e22799C,
            0xedf6066a2b290C185783862C7F4776A2C8077AD1,
            0xec7BE89e9d109e7e3Fec59c222CF297125FEFda2,
            0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f
        )
    {
        transferRewardPoolFeeFraction = 100;

        minSegmentVoteCount = 1;

        composerAddress = address(new Composer());

        pendingComposerAddress = composerAddress;

        _decimals = 9; // initially using gwei units for simplicity

        addLP(0xe53bF56F8E5BfC508A08cD2C375c0257044114F7);

        _mint(msg.sender, 500000 gwei);
        _mint(address(this), 500000 gwei);
    }

    function newProposalRequirement() internal view returns (uint256) {
        return totalSupply() / (THRESHOLD_FRACTION * 100); // requiring 1% of pass to initiate a vote
    }

    function activatePendingComposer() internal {
        if (
            pendingComposerAddress != composerAddress
        ) {
            composerAddress = pendingComposerAddress;
        }
    }

    function createProposal(address target, Proposals _proposal) external {
        Proposal storage proposal = proposals[target];
        require(proposal.proposal == Proposals.EMPTY);

        proposal.proposal = _proposal;
        proposal.voteCount = 0;

        vote(target, newProposalRequirement());
    }

    function vote(address target, uint256 amount) public {
        // a single vote must be less than that of the initial requirement
        require(amount <= newProposalRequirement());

        Proposal storage proposal = proposals[target];

        Voter storage voter = votes[msg.sender];

        require(proposal.proposal != Proposals.EMPTY);

        require(voter.lockedAmount == 0);

        _transfer(msg.sender, target, amount);

        proposal.voteCount += amount;
        voter.lockedAmount = amount;
        voter.target = target;
        voter.timestamp = uint64(block.timestamp);

        if (proposal.voteCount > totalSupply() / THRESHOLD_FRACTION) {
            passProposal(proposal.proposal, target);
            proposal.proposal = Proposals.EMPTY;
            proposal.voteCount = 0;
        }
    }

    function passProposal(Proposals proposal, address target) internal {
        if (proposal == Proposals.NEW_LP) {
            addLP(target);
        } else if (proposal == Proposals.REMOVE_LP) {
            removeLP(target);
        } else if (proposal == Proposals.NEW_COMPOSER) {
            pendingComposerAddress = target;
        } else if (proposal == Proposals.CHANGE_FEE) {
            transferRewardPoolFeeFraction = target == address(1) && transferRewardPoolFeeFraction > 25
                ? transferRewardPoolFeeFraction / 2
                : transferRewardPoolFeeFraction * 2;
        } else if (proposal == Proposals.ADJUST_DECIMALS) {
            _decimals = target == address(1) && _decimals > 3
                ? _decimals - 1
                : _decimals + 1;
        } else if (proposal == Proposals.CHANGE_SEGMENT_LENGTH) {
            changeSegmentLength(uint64(uint160(target)));
        } else if (proposal == Proposals.CHANGE_MIN_SEGMENT_VOTE) {
            minSegmentVoteCount = uint16(uint160(target));
        }

        emit ProposalPassed(proposal, target);
    }

    function withdraw() external {
        Voter storage voter = votes[msg.sender];
        Proposal storage proposal = proposals[voter.target];

        require(voter.lockedAmount > 0);

        // votes are locked for 14 days
        require(block.timestamp - voter.timestamp > 14 days);

        _transfer(voter.target, msg.sender, voter.lockedAmount);

        // if not passed yet, need to remove from current votes
        if (proposal.voteCount >= voter.lockedAmount) proposal.voteCount -= voter.lockedAmount;

        voter.lockedAmount = 0;
    }

    function getRewardsPerTx(uint256 value) internal view returns (uint256) {
        return value / transferRewardPoolFeeFraction;
    }
}

