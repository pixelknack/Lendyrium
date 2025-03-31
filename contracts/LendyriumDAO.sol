// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./LendyriumToken.sol";

contract LendyriumDAO {
    struct Proposal {
        address proposer;
        address target;
        string functionSignature;
        bytes parameters;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 endTime;
        uint256 snapshotBlock;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public nextProposalId;
    LendyriumToken public governanceToken;
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public proposalThreshold = 1000e18;

    event ProposalCreated(uint256 proposalId, address proposer, address target, string functionSignature);
    event Voted(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 proposalId);

    constructor(address _governanceToken) {
        governanceToken = LendyriumToken(_governanceToken);
    }

    function createProposal(
        address _target, 
        string memory _functionSignature, 
        bytes memory _parameters
    ) external {
        require(
            governanceToken.balanceOf(msg.sender) >= proposalThreshold, 
            "Insufficient balance"
        );
        
        proposals[nextProposalId] = Proposal({
            proposer: msg.sender,
            target: _target,
            functionSignature: _functionSignature,
            parameters: _parameters,
            yesVotes: 0,
            noVotes: 0,
            endTime: block.timestamp + VOTING_PERIOD,
            snapshotBlock: block.number,
            executed: false
        });
        
        emit ProposalCreated(nextProposalId, msg.sender, _target, _functionSignature);
        nextProposalId++;
    }

    function vote(uint256 _proposalId, bool _support) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.endTime, "Voting ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        
        uint256 votes = governanceToken.votingPower(msg.sender);
        _support ? proposal.yesVotes += votes : proposal.noVotes += votes;
        hasVoted[_proposalId][msg.sender] = true;
        
        emit Voted(_proposalId, msg.sender, _support);
    }

    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.endTime, "Voting ongoing");
        require(!proposal.executed, "Already executed");
        require(proposal.yesVotes > proposal.noVotes, "Proposal failed");
        
        proposal.executed = true;
        (bool success,) = proposal.target.call(
            abi.encodeWithSignature(proposal.functionSignature, proposal.parameters)
        );
        require(success, "Execution failed");
        emit ProposalExecuted(_proposalId);
    }

    // Helper function to get voting power at proposal snapshot
    function getVotes(address account, uint256 proposalId) public view returns (uint256) {
        Proposal memory proposal = proposals[proposalId];
        return governanceToken.votingPower(account);
    }
}