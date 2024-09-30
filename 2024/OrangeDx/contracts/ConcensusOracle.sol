
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


error notCaller();
error unauthorised();
error roleAlreadyGranted();
error alreadyGranted();
error alreadyRevoked();
error closed();
error failedCall();

struct Proposal{
    uint256 id;
    address target;
    bytes callData;
    string description;
    uint256 votes;
    bool executed;
    bool success;
    bytes result;
}

contract ConcensusOracle is AccessControl,ReentrancyGuard{
    bytes32 public VALIDATOR_ROLE = keccak256('VALIDATOR_ROLE');
    uint256 public nodes;
    uint256 proposal_count = 0;

    mapping(uint256=>Proposal) public proposals;
    mapping(string=>uint256) public btcTxProposalId;
    mapping(address=>mapping(uint=>bool)) public voteInfo;

    event Proposed(uint256 id,address indexed proposer);
    event Executed(uint256 id);
    // use byzantine fault tolerance for no of nodes to run
    constructor(address[] memory callers){
        nodes = callers.length;
        for(uint8 i = 0; i < callers.length;i ++){
            _grantRole(VALIDATOR_ROLE,callers[i]);
        }
    }

    function rotateCaller(address new_caller) public onlyRole(VALIDATOR_ROLE) {
        _grantRole(VALIDATOR_ROLE,new_caller);
        _revokeRole(VALIDATOR_ROLE,msg.sender);
    }

    function removeValidator(address _validator) public onlySelf {
        if(!hasRole(VALIDATOR_ROLE,_validator)){
            revert alreadyRevoked();
        }
        _revokeRole(VALIDATOR_ROLE, _validator);
        nodes-=1;
    }
    function addValidator(address _validator) public onlySelf {
        if(hasRole(VALIDATOR_ROLE,_validator)){
            revert alreadyGranted();
        }
        _grantRole(VALIDATOR_ROLE, _validator);
        nodes+=1;
    }

    function faultTolerance() public view returns(uint256){
        return (nodes-1)/3;
    }
    function proposeAddValidator(address _validator) external onlyRole(VALIDATOR_ROLE) returns(uint256 id){
        bytes memory encodedCall = abi.encodeWithSelector(this.addValidator.selector, _validator);
        id =_propose(address(this),encodedCall,"addValidator(address)");
    }

    function requiredMajority() public view returns(uint256) {
        return (nodes + faultTolerance() + 1) / 2;
    }

    function executeProposal(uint256 id) internal returns (bool success, bytes memory result) {
        Proposal storage p = proposals[id];
        (success, result) = address(p.target).call(p.callData);
        if(success){
            p.success=true;
        }
        else{
            revert failedCall();
        }
        p.executed = true;
        p.result = result;
        emit Executed(id);
    }

    function voteForProposal(uint256 id,bool vote) external nonReentrant{
        Proposal storage p = proposals[id];
        if(p.executed){
            revert closed();
        }
        uint256 requiredVotes = requiredMajority();
        if(vote && voteInfo[msg.sender][id]==false){
            p.votes+=1;
            voteInfo[msg.sender][id]= true;
        }else if(voteInfo[msg.sender][id] && !vote){
            p.votes-=1;
            voteInfo[msg.sender][id]= false;
        }   
        if(p.votes>= requiredVotes){
            executeProposal(id);
        }
    }

    function propseRemoveValidator(address _validator) external onlyRole(VALIDATOR_ROLE) returns(uint256 id){
        bytes memory encodedCall = abi.encodeWithSelector(this.removeValidator.selector, _validator);
        id = _propose(address(this),encodedCall,"removeValidator(address)");
    }



    function proposeUpdateBRC20Complete(uint256 depositId,address _bridge,string memory btcTX) external onlyRole(VALIDATOR_ROLE) returns(uint256 id){
        bytes memory encodedCall = abi.encodeWithSignature("updateCompleteBRC20Exit(uint256,string)", depositId,btcTX);
        id = _propose(_bridge,encodedCall,"updateCompleteBRC20Exit(uint256,string)");
        btcTxProposalId[btcTX] = id;
    }

    function proposeUpdateDepositBRC20(
        address _bridge,
        string memory txHash,
        string memory ticker,
        uint256 amount,
        address wallet,
        string memory btcAddress) external onlyRole(VALIDATOR_ROLE) returns(uint256 id){
        bytes memory encodedCall = abi.encodeWithSignature(
            "depositBRC20(string,string,uint256,address,string)", txHash,ticker,amount,wallet,btcAddress);
            id = _propose(_bridge,encodedCall,"depositBRC20(string,string,uint256,address,string)"); 
        btcTxProposalId[txHash] = id;
    }


    function _propose(address target,bytes memory callData,string memory description) public returns(uint256) {  ///@audit internal modifier
        proposal_count+=1;
        Proposal memory p = Proposal(
            proposal_count,
            target,
            callData,
            description,
            1,
            false,
            false,
            ""
        );
        proposals[proposal_count] = p;
        voteInfo[msg.sender][proposal_count] = true;
        emit Proposed(proposal_count,msg.sender);
        return proposal_count;
    }
    modifier onlySelf() {
        if(msg.sender != address(this)){
            revert unauthorised();
        }
        _;
    }

}