// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IWithDAO.sol";
import "./_Proposals.sol";

contract DAO {
    uint256 constant THRESHOLD_FRACTION = 15; // 1 / 15th of total supply is required for a proposal to pass

    address owner;

    struct Voter {
        address target;
        uint64 timestamp;
        uint256 lockedAmount;
    }

    struct Proposal {
        _Proposals.Proposals proposal;
        uint256 voteCount;
    }

    mapping(address => Proposal) public proposals;
    mapping(address => Voter) votes;

    event ProposalPassed(_Proposals.Proposals proposal, address target);

    constructor() {
        owner = msg.sender;
    }

    function newProposalRequirement() internal view returns (uint256) {
        return IERC20(owner).totalSupply() / (THRESHOLD_FRACTION * 100); // requiring 1% of pass to initiate a vote
    }

    function createProposal(address target, _Proposals.Proposals _proposal)
        external
    {
        Proposal storage proposal = proposals[target];
        require(proposal.proposal == _Proposals.Proposals.EMPTY);

        proposal.proposal = _proposal;
        proposal.voteCount = 0;

        vote(target, newProposalRequirement());
    }

    function hasPassed(Proposal memory proposal) internal view returns (bool) {
        return
            proposal.voteCount >
            IERC20(owner).totalSupply() / THRESHOLD_FRACTION &&
            (proposal.proposal != _Proposals.Proposals.CHANGE_DAO ||
                proposal.voteCount >
                IERC20(owner).totalSupply() / (THRESHOLD_FRACTION / 5));
    }

    function vote(address target, uint256 amount) public {
        // a single vote must be less than that of the initial requirement
        require(amount <= newProposalRequirement());

        Proposal storage proposal = proposals[target];

        Voter storage voter = votes[msg.sender];

        require(proposal.proposal != _Proposals.Proposals.EMPTY);

        require(voter.lockedAmount == 0);

        // requires external approval. 
        IERC20(owner).transferFrom(msg.sender, address(this), amount);

        proposal.voteCount += amount;
        voter.lockedAmount = amount;
        voter.target = target;
        voter.timestamp = uint64(block.timestamp);

        if (hasPassed(proposal)) {
            IWithDAO(owner).passProposal(proposal.proposal, target);
            emit ProposalPassed(proposal.proposal, target);
            proposal.proposal = _Proposals.Proposals.EMPTY;
            proposal.voteCount = 0;
        }
    }

    function withdraw() external {
        Voter storage voter = votes[msg.sender];
        Proposal storage proposal = proposals[voter.target];

        require(voter.lockedAmount > 0);

        // votes are locked for 14 days
        require(block.timestamp - voter.timestamp > 14 days);

        IERC20(owner).transfer(msg.sender, voter.lockedAmount);

        // if not passed yet, need to remove from current votes
        if (proposal.voteCount >= voter.lockedAmount)
            proposal.voteCount -= voter.lockedAmount;

        voter.lockedAmount = 0;
    }
}

