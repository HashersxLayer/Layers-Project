// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.0;

contract Voting {
    struct Voter {
        uint256 weight;
        bool voted;
        address delegate;
        uint256 vote;
    }

    struct Proposal {
        bytes32 name;
        uint256 voteCount;
    }

    address public chairperson;
    mapping(address => Voter) public voterRegistry;
    Proposal[] public proposals;

    constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;
        voterRegistry[chairperson].weight = 1;

        for (uint256 i = 0; i < proposalNames.length; i++) {
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }

    function giveRightToVote(address voter) public {
        require(msg.sender == chairperson && !voterRegistry[voter].voted && voterRegistry[voter].weight == 0);
        voterRegistry[voter].weight = 1;
    }

    function delegate(address to) public {
        Voter storage sender = voterRegistry[msg.sender];
        require(!sender.voted);
        require(to != msg.sender);

        _delegate(to, sender.weight);

        sender.voted = true;
        sender.delegate = to;
    }

    function vote(uint256 proposal) public {
        Voter storage sender = voterRegistry[msg.sender];
        require(!sender.voted);
        sender.voted = true;
        sender.vote = proposal;
        proposals[proposal].voteCount += sender.weight;
    }

    function winningProposal() public view returns (uint256 winningProposal_) {
        uint256 winningVoteCount = 0;
        for (uint256 p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    function winnerName() public view returns (bytes32 winnerName_) {
        winnerName_ = proposals[winningProposal()].name;
    }

    function _delegate(address to, uint256 weight) internal {
        Voter storage delegateVoter = voterRegistry[to];
        if (delegateVoter.voted) {
            proposals[delegateVoter.vote].voteCount += weight;
        } else {
            delegateVoter.weight += weight;
            if (delegateVoter.delegate != address(0)) {
                _delegate(delegateVoter.delegate, weight);
            }
        }
    }
}