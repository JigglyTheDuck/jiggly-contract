// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IJiggly.sol";

contract DAO {
    uint256 constant THRESHOLD_FRACTION = 10; // 10% of total supply is required for a proposal to pass

    struct Voter {
        address target;
        uint64 timestamp;
        uint256 lockedAmount;
    }

    struct Proposal {
        uint8 proposal;
        uint64 timestamp;
        uint184 voteCount;
    }

    address owner;
    mapping(address => Proposal) public proposals;
    mapping(address => Voter) votes;

    event ProposalPassed(uint8, address target);
    event NewProposal(uint8, address);

    constructor() {
        owner = msg.sender;
    }

    function newProposalRequirement() internal view returns (uint256) {
        return IERC20(owner).totalSupply() / (THRESHOLD_FRACTION * 100); // requiring 0.1% to initiate a vote
    }

    function getBalance() internal view returns (uint256) {
        return IERC20(owner).balanceOf(address(this));
    }

    function createProposal(address target, uint8 _proposal) external {
        Proposal storage proposal = proposals[target];
        require(
            proposal.proposal == 0 ||
                (block.timestamp - proposal.timestamp) > 30 days
        );

        proposal.proposal = _proposal;
        proposal.voteCount = 0;
        proposal.timestamp = uint64(block.timestamp);

        vote(target, newProposalRequirement());

        emit NewProposal(_proposal, target);
    }

    function hasPassed(Proposal memory proposal) internal view returns (bool) {
        return
            proposal.voteCount >=
            IERC20(owner).totalSupply() /
                (
                    proposal.proposal < 3 // Major contract changes require more votes and take effect immediately
                        ? (THRESHOLD_FRACTION * 2) / 5 // 25%
                        : THRESHOLD_FRACTION
                );
    }

    function vote(address target, uint256 amount) public {
        // a single vote must be less than that of the initial requirement
        require(amount <= newProposalRequirement());

        Proposal storage proposal = proposals[target];

        Voter storage voter = votes[msg.sender];

        require(
            proposal.proposal != 0 &&
                (block.timestamp - proposal.timestamp) < 30 days
        );

        require(voter.lockedAmount == 0);

        // requires external approval.
        IERC20(owner).transferFrom(msg.sender, address(this), amount);

        proposal.voteCount += uint184(amount);
        voter.lockedAmount = amount;
        voter.target = target;
        voter.timestamp = uint64(block.timestamp);

        if (hasPassed(proposal)) {
            IJiggly(owner).passProposal(proposal.proposal - 1, target);
            emit ProposalPassed(proposal.proposal - 1, target);
            proposal.proposal = 0;
            proposal.voteCount = 0;
        }
    }

    function withdraw() external {
        Voter storage voter = votes[msg.sender];
        Proposal storage proposal = proposals[voter.target];

        require(voter.lockedAmount > 0);

        // votes are locked for 14 days unless passed in the meantime
        require(
            proposal.proposal == 0 ||
                block.timestamp - voter.timestamp > 14 days
        );

        IERC20(owner).transfer(msg.sender, voter.lockedAmount);

        // if not passed yet, need to remove from current votes
        if (proposal.voteCount >= voter.lockedAmount)
            proposal.voteCount -= uint184(voter.lockedAmount);

        voter.lockedAmount = 0;
    }
}

