// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BountyJudge {
    enum Stage { Submission, Reveal, Judging, Completed }
    
    struct Bounty {
        string description;
        uint256 reward;
        Stage stage;
        address winner;
    }

    mapping(uint256 => Bounty) public bounties;
    mapping(uint256 => mapping(address => bytes32)) public commitments;
    mapping(uint256 => string[]) private revealedAnswers;
    mapping(uint256 => address[]) private revealedUsers;

    address public owner;
    uint256 public nextBountyId;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createBounty(string calldata _desc) external payable {
        bounties[nextBountyId] = Bounty(_desc, msg.value, Stage.Submission, address(0));
        nextBountyId++;
    }

    function submitCommitment(uint256 bountyId, bytes32 commitment) external {
        require(bounties[bountyId].stage == Stage.Submission, "Not submission stage");
        commitments[bountyId][msg.sender] = commitment;
    }

    function changeStageToReveal(uint256 bountyId) external onlyOwner {
        bounties[bountyId].stage = Stage.Reveal;
    }

    function revealAnswer(uint256 bountyId, string calldata answer, bytes32 salt) external {
        require(bounties[bountyId].stage == Stage.Reveal, "Not reveal stage");
        
        bytes32 expectedCommitment = keccak256(abi.encodePacked(answer, salt, msg.sender, bountyId));
        require(commitments[bountyId][msg.sender] == expectedCommitment, "Invalid commitment");

        revealedAnswers[bountyId].push(answer);
        revealedUsers[bountyId].push(msg.sender);
    }

    function changeStageToJudging(uint256 bountyId) external onlyOwner {
        bounties[bountyId].stage = Stage.Judging;
    }

    function judgeAll(uint256 bountyId, bytes calldata llmInput) external onlyOwner view returns (string[] memory) {
        require(bounties[bountyId].stage == Stage.Judging, "Not judging stage");
        return revealedAnswers[bountyId];
    }

    function finalizeWinner(uint256 bountyId, uint256 winnerIndex) external onlyOwner {
        require(bounties[bountyId].stage == Stage.Judging, "Not judging stage");
        require(winnerIndex < revealedUsers[bountyId].length, "Invalid winner index");

        address winnerAddress = revealedUsers[bountyId][winnerIndex];
        Bounty storage bounty = bounties[bountyId];
        
        bounty.winner = winnerAddress;
        bounty.stage = Stage.Completed;

        payable(winnerAddress).transfer(bounty.reward);
    }
}
