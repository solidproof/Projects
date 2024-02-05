pragma solidity ^0.8.9;
import "./Clones.sol";
import "./CampaignV0.sol";

contract CampaignV0Factory {
  address public admin;
  address public feeBenefactor;
  address public campaignV0Implementation;
  mapping (address => uint64) public initializedCampaigns;
  address[] public campaigns;
  uint64 public fee; //the fee for newly created campaigns scaled by 10,000 (25 = 0.0025 = 0.25%)

  function getAllCampaigns() public view returns (address[] memory) {
    return campaigns;
  }

  modifier onlyAdmin {
    require(msg.sender == admin, "Only the admin can call this function");
    _;
  }

  function setFee(uint64 _newFee) public onlyAdmin {
    fee = _newFee;
  }

  function transferAdmin(address _newAdmin) public onlyAdmin {
    admin = _newAdmin;
  }

  function transferBenefactor(address _newBenefactor) public onlyAdmin {
    feeBenefactor = _newBenefactor;
  }

  event campaignCreated(address campaign, address indexed creator);

  constructor(address _campaignV0Implementation) {
    campaignV0Implementation = _campaignV0Implementation;
    admin = msg.sender;
    feeBenefactor = msg.sender;
    fee = 0;
  }

  function createCampaign(uint64 _deadline, uint256 _fundingGoal, uint256 _fundingMax, string calldata _title, string calldata _description) public returns (address newCampaign) {
    address clone = Clones.clone(campaignV0Implementation);
    CampaignV0(clone).init(msg.sender, _deadline, _fundingGoal, _fundingMax, _title, _description, fee);
    emit campaignCreated(clone, msg.sender);
    initializedCampaigns[clone] = uint64(block.timestamp);
    campaigns.push(clone);
    return clone;
  }
}