// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendyriumDAO {
    struct Proposal {
        address proposer;
        address target;
        string functionSignature;
        bytes parameters;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 endTime;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public nextProposalId;
    IERC20 public governanceToken;
    uint256 public constant VOTING_PERIOD = 3 days;

    event ProposalCreated(uint256 proposalId, address proposer, address target, string functionSignature);
    event Voted(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 proposalId);

    constructor(address _governanceToken) {
        governanceToken = IERC20(_governanceToken);
    }

    function createProposal(address _target, string memory _functionSignature, bytes memory _parameters) external {
        proposals[nextProposalId] = Proposal({
            proposer: msg.sender,
            target: _target,
            functionSignature: _functionSignature,
            parameters: _parameters,
            yesVotes: 0,
            noVotes: 0,
            endTime: block.timestamp + VOTING_PERIOD,
            executed: false
        });
        emit ProposalCreated(nextProposalId, msg.sender, _target, _functionSignature);
        nextProposalId++;
    }

    function vote(uint256 _proposalId, bool _support) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.endTime, "Voting period ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        uint256 voterBalance = governanceToken.balanceOf(msg.sender);
        if (_support) {
            proposal.yesVotes += voterBalance;
        } else {
            proposal.noVotes += voterBalance;
        }
        hasVoted[_proposalId][msg.sender] = true;
        emit Voted(_proposalId, msg.sender, _support);
    }

    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Already executed");
        require(proposal.yesVotes > proposal.noVotes, "Proposal did not pass");
        proposal.executed = true;
        (bool success, ) = proposal.target.call(abi.encodeWithSignature(proposal.functionSignature, proposal.parameters));
        require(success, "Execution failed");
        emit ProposalExecuted(_proposalId);
    }
}