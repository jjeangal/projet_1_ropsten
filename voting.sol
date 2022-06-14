// contracts/Voting.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Voting System
/// @author Jean Gal
contract Voting is Ownable {
    using Counters for Counters.Counter;

    // Counter for number of proposals
    Counters.Counter private _proposalCounter;
    // Current status of the session 
    WorkflowStatus status;
    // Id of the winner proposal
    uint winningProposalId;

    /// Event to be triggered when the current status of the voting session changes
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    /// Event to be triggered when a voter gets registered    
    event VoterRegistered(address voterAddress); 
    /// Event to be triggered when a voter gets unregistered and can't vote in the current session  
    event VoterUnregistered(address voterAddress); 
    /// Event to be triggered when a proposal gets registered 
    event ProposalRegistered(uint proposalId);
    /// Event to be triggered when a voter votes
    event Voted(address voter, uint proposalId);
    /// Event to be triggered when two proposals have the same vote count
    event ProposalDraw(uint proposalOneId, uint proposalTwoId);

    /// Voter struct object
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    /// Proposal struct object
    struct Proposal {
        string description;
        uint voteCount;
    }

    /// Enum for all status of the voting session
    enum WorkflowStatus {
        RegisteringVoters,              // 0
        ProposalsRegistrationStarted,   // 1
        ProposalsRegistrationEnded,     // 2
        VotingSessionStarted,           // 3
        VotingSessionEnded,             // 4
        VotesTallied                    // 5
    }

    /// Maps addresses of voters to Voter structs
    mapping(address => Voter) votersList;
    /// Keep a list of proposals
    Proposal[] private proposalsList;
    /// Keep a list of the voters addresses
    address[] private voterAddresses;

    constructor() {
        // Initiliase the status on contract creation.
        status = WorkflowStatus.RegisteringVoters;  
        // Let the first id be 1
        _proposalCounter.increment();
        // Initialize some voters
        addVoter(0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB);
        addVoter(0x583031D1113aD414F02576BD6afaBfb302140225);
        addVoter(0xdD870fA1b7C4700F2BD7f44238821C26f7392148);
    }

    /* @notice  Modifier to attach when a status can only be changed from one specific 
    *           status to another
    *  @param   _status The status from which there can be a transition
    */
    modifier atStage(WorkflowStatus _status) {
        require(
            status == _status,
            "Function cannot be called at this time. Wait for the adequate session."
        );
        _;
    }

    /// @notice Address must be associated with existing voter
    modifier beVoter(address _voterAddress) {
        require(isVoter(_voterAddress), "Not a voter.");
        _;
    }

    /// @notice Start the proposal registration phase of the voting session
    function startProposalRegistration() public onlyOwner atStage(WorkflowStatus(0)) {
        status = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, status);
    }

    /// @notice Close the proposal registration phase of the voting session
    function closeProposalRegistration() public onlyOwner atStage(WorkflowStatus(1)) {
        status = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, status);        
    }

    /// @notice Start the voting registration phase of the voting session
    function startVotingSession() public onlyOwner atStage(WorkflowStatus(2)) {
        status = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, status);
    }

    /// @notice Close the voting registration phase of the voting session
    function closeVotingSession() public onlyOwner atStage(WorkflowStatus(3)) {
        status = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, status);
    }

    /// @notice Start the vote tally phase of the voting session and set the winner
    function openVoteTally() public onlyOwner atStage(WorkflowStatus(4)) {
        status = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, status);
        setWinner();
    }

    /// @notice Restart the voting session
    /// @dev Reinitialize proposals, votes, the winner & voters if wanted
    /// @param removeVoters A bool value that defines if voters should be removed from session
    function restartVotingSession(bool removeVoters) public onlyOwner atStage(WorkflowStatus(5)) {
        status = WorkflowStatus(0);
        int voterArraySize = int(voterAddresses.length);
        address temp;
        for (int i = voterArraySize - 1; i >= 0; i--) {
            temp = voterAddresses[uint(i)];
            if (removeVoters) {
                removeVoter(temp);
                voterAddresses.pop();
            } else {
                votersList[temp] = Voter(true, false, 0);
            }
        }
        winningProposalId = 0;
        deleteAllProposals();
    }

    /// @notice Add a voter to the session
    /// @param _voterAddress The address of the voter to be added
    function addVoter(address _voterAddress) public onlyOwner atStage(WorkflowStatus(0)) {
        require(votersList[_voterAddress].isRegistered == false, "Voter already takes part in the session.");
        votersList[_voterAddress].isRegistered = true;
        voterAddresses.push(_voterAddress);
        emit VoterRegistered(_voterAddress);
    }

    /// @notice Unregister a voter without deleting him from the session
    /// @param _voterAddress The address of the voter to be unregistered
    function removeVoter(address _voterAddress) public onlyOwner atStage(WorkflowStatus(0)) {
        if (votersList[_voterAddress].isRegistered == true) {
            votersList[_voterAddress] = Voter(false, false, 0);
            emit VoterUnregistered(_voterAddress);
        }
    }

    /// @notice Add a proposal to the list of all proposals
    /// @param _description The description of the proposal to be added
    function addProposal(string calldata _description) public beVoter(msg.sender) atStage(
        WorkflowStatus(1)) {
        uint256 newId = _proposalCounter.current();
        _proposalCounter.increment();
        proposalsList.push(Proposal(_description, 0));
        emit ProposalRegistered(newId);
    }

    /// @notice Allows a voter to vote for a proposal
    /// @dev Voter must exist and be registered
    /// @param _proposalId The id of the proposal to be voted for
    function vote(uint _proposalId) public beVoter(msg.sender) atStage(WorkflowStatus(3)) {
        require(votersList[msg.sender].hasVoted == false, "You have already voted.");
        require(_proposalId <= _proposalCounter.current() - 1, "This proposal doesn't exist.");
        require(_proposalId != 0, "Proposal 0 does not exist");        

        proposalsList[_proposalId-1].voteCount += 1;
        votersList[msg.sender].votedProposalId = _proposalId;
        votersList[msg.sender].hasVoted = true;
        emit Voted(msg.sender, _proposalId);
    }

    /// @notice Allows a voter to revoke is vote for another
    /// @dev Calls a private function to lower voteCount of first voted proposal
    /// @param _proposalId The id of the proposal to be voted for
    function changeVote(uint _proposalId) public beVoter(msg.sender) atStage(WorkflowStatus(3)) {
        require(votersList[msg.sender].hasVoted == true, "There is no vote to be changed.");
        require(_proposalId <= _proposalCounter.current() - 1, "This proposal doesn't exist."); 
        require(_proposalId != 0, "Proposal 0 does not exist");    
        removeVoteOf(msg.sender);
        votersList[msg.sender].votedProposalId = _proposalId;
        proposalsList[_proposalId-1].voteCount++;
    }

    /// @notice Returns the current status of the session
    /// @dev Function returns a uint corresponding to a status
    function getStatus() public view returns(WorkflowStatus) {
        return status;
    }

    /// @notice Returns the winner of the vote.
    function getWinner() public view atStage(WorkflowStatus(5)) returns(uint) {
        require(winningProposalId != 0, "No winner was chosen.");
        return winningProposalId;
    }

    /// @notice Return the list containing all voters addresses
    function getVoters() public view returns(address[] memory) {
        return voterAddresses;
    }

    /// @notice Return the voter's information
    /// @param _voterAddress The address of the voter
    function getVoter(address _voterAddress) public view beVoter(msg.sender) returns(
        Voter memory) {
        return (votersList[_voterAddress]);
    }

    /// @notice Returns the id of the proposal for which the voter voted for
    /// @param _voterAddress The adress of the voter
    function getVotedProposal(address _voterAddress) public view beVoter(
        msg.sender) returns(uint) {
        require(votersList[_voterAddress].hasVoted == true, "Voter did not vote.");
        return votersList[_voterAddress].votedProposalId;
    }

    /// @notice Returns the description and number of votes of a proposal
    /// @param _proposalId The id of the proposal to be fetched
    /// @return The proposal associated to the id
    function getProposal(uint _proposalId) public view returns (Proposal memory) {
        require(_proposalId < _proposalCounter.current(), "This proposal doesn't exist.");
        require(_proposalId != 0, "The proposal 0 is not defined.");
        return (proposalsList[_proposalId-1]);
    }

    /// @notice Returns the list of all proposals
    function getAllProposals() public view returns (Proposal[] memory) {
        return proposalsList;
    }

    /// @notice Sets the winner of the voting session
    /// @dev The id of a proposal equals its position in the array + 1
    function setWinner() private onlyOwner atStage(WorkflowStatus(5)) {
        uint numberOfProposals = _proposalCounter.current() - 1;                 // Counter starts at '1'.
        uint pos = 0;        
        for (uint i = 1; i < numberOfProposals; i++) {
            if(proposalsList[i].voteCount > proposalsList[pos].voteCount) {
                pos = i;                                             
            }
            if(proposalsList[i].voteCount == proposalsList[pos].voteCount) {
                pos = handleEquality(pos, i);
            }
        }
        if (numberOfProposals > 0 && proposalsList[pos].voteCount > 0) {
            winningProposalId = pos + 1;
        }  
    }

    /// @notice Delete all existing proposals
    function deleteAllProposals() private onlyOwner {
        _proposalCounter.reset();
        _proposalCounter.increment();
        delete proposalsList;
    }

    /// @notice Lowers the vote count of the voter's voted proposal
    function removeVoteOf(address _voterAddress) private {
        uint currentId = getVotedProposal(_voterAddress);
        proposalsList[currentId-1].voteCount--;
    }

    /// @notice Brakes draws between two proposals
    /// @param id1 id2 The ids of the two proposals to compare
    /// @return The id of the oldest proposal (for now)
    function handleEquality(uint id1, uint id2) private returns (uint) {
        emit ProposalDraw(id1, id2);
        /// To be developed
        return id1;
    }

    /// @notice Verify if the passed address corresponds to a voter
    /// @param _voterAddress The address to be verified
    /// @return True if address is associated to a voter
    function isVoter(address _voterAddress) private view returns (bool) {
        return votersList[_voterAddress].isRegistered;
    }
}
