// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interfaces/IKonduxERC20.sol";
import "./types/AccessControlled.sol";

/**
 * @title Treasury
 * @dev This contract handles deposits and withdrawals of tokens and Ether.
 */
contract Treasury is AccessControlled {

    /* ========== EVENTS ========== */

    event Deposit(address indexed token, uint256 amount);
    event DepositEther(uint256 amount);
    event EtherDeposit(uint256 amount);
    event Withdrawal(address indexed token, uint256 amount);
    event EtherWithdrawal(address to, uint256 amount);

    /* ========== DATA STRUCTURES ========== */

    enum STATUS {
        RESERVEDEPOSITOR,
        RESERVESPENDER,
        RESERVETOKEN
    }

    /* ========== STATE VARIABLES ========== */

    string internal notAccepted = "Treasury: not accepted";
    string internal notApproved = "Treasury: not approved";
    string internal invalidToken = "Treasury: invalid token";

    mapping(STATUS => mapping(address => bool)) public permissions;
    mapping(address => bool) public isTokenApproved;
    
    address[] public approvedTokensList;
    uint256 public approvedTokensCount;

    address public stakingContract;

    /**
     * @dev Initializes the Treasury contract.
     * @param _authority The address of the authority contract.
     */
    constructor(address _authority) AccessControlled(IAuthority(_authority)) {
        approvedTokensCount = 0;
    }

    /**
     * @notice Allow approved address to deposit an asset for Kondux.
     * @dev Deposits a specified amount of the specified token.
     * @param _amount The amount of tokens to deposit.
     * @param _token The address of the token contract.
     */
    function deposit(
        uint256 _amount,
        address _token
    ) external {
        if (permissions[STATUS.RESERVETOKEN][_token]) {
            require(permissions[STATUS.RESERVEDEPOSITOR][msg.sender], notApproved);
        } else {
            revert(invalidToken);
        }

        IKonduxERC20(_token).transferFrom(tx.origin, address(this), _amount);
        // get allowance and increase it
        uint256 allowance = IKonduxERC20(_token).allowance(stakingContract, _token);
        IKonduxERC20(_token).approve(stakingContract, allowance + _amount);

        emit Deposit(_token, _amount);
    }

    /**
     * @notice Allow approved address to deposit Ether.
     * @dev Deposits Ether to the contract.
     */
    function depositEther () external payable {
        require(permissions[STATUS.RESERVEDEPOSITOR][msg.sender], notApproved);  
                
        emit DepositEther(msg.value);
    }

    /**
     * @notice Allow approved address to withdraw Kondux from reserves.
     * @dev Withdraws a specified amount of the specified token.
     * @param _amount The amount of tokens to withdraw.
     * @param _token The address of the token contract.
     */
    function withdraw(uint256 _amount, address _token) external {
        require(permissions[STATUS.RESERVETOKEN][_token], notAccepted); // Only reserves can be used for redemptions
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);

        IKonduxERC20(_token).transfer(msg.sender,         _amount);

        emit Withdrawal(_token, _amount);
    }

    /**
     * @dev Receives Ether.
     */
    receive() external payable {
        emit EtherDeposit(msg.value);
    }

    /**
     * @dev Fallback function for receiving Ether.
     */
    fallback() external payable { 
        emit EtherDeposit(msg.value); 
    }
    
    /**
     * @notice Allow approved address to withdraw Ether.
     * @dev Withdraws a specified amount of Ether.
     * @param _amount The amount of Ether to withdraw.
     */
    function withdrawEther(uint _amount) external {
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);
        require(payable(msg.sender).send(_amount));

        emit EtherWithdrawal(msg.sender, _amount);
    }

    /**
     * @dev Sets permissions for the specified address.
     * @param _status The status to set the permission for.
     * @param _address The address to set the permission for.
     * @param _permission The permission value to set.
     */
    function setPermission(
        STATUS _status,
        address _address,
        bool _permission
    ) public onlyGovernor {
        // Check if the address is non-zero
        require(_address != address(0), "Treasury Permission: zero address");
        permissions[_status][_address] = _permission;
        if (_status == STATUS.RESERVETOKEN) {
            isTokenApproved[_address] = _permission;
            if (_permission) {
                approvedTokensList.push(_address);
                approvedTokensCount++;                
            }
        }
    }

    /**
     * @dev Sets the staking contract address.
     * @param _stakingContract The address of the staking contract.
     */
    function setStakingContract(address _stakingContract) public onlyGovernor {
        // Check if the address is non-zero
        require(_stakingContract != address(0), "Treasury SetStakingContract: zero address");
        require(_stakingContract != stakingContract, "Treasury SetStakingContract: same address");
        
        stakingContract = _stakingContract;
    }

    /**
     * @dev Sets up the ERC20 token approval.
     * @param _token The address of the token contract.
     * @param _amount The amount to approve.
     */
    function erc20ApprovalSetup(address _token, uint256 _amount) public onlyGovernor {
        IKonduxERC20(_token).approve(stakingContract, _amount);
    }

    // Getters

    /**
     * @dev Returns the list of approved tokens.
     * @return An array of approved token addresses.
     */
    function getApprovedTokensList() public view returns (address[] memory) {
        return approvedTokensList;
    }

    /**
     * @dev Returns the count of approved tokens.
     * @return The number of approved tokens.
     */
    function getApprovedTokensCount() public view returns (uint256) {
        return approvedTokensCount;
    }

    /**
     * @dev Returns the approved token at the specified index.
     * @param _index The index of the approved token.
     * @return The address of the approved token at the given index.
     */
    function getApprovedToken(uint256 _index) public view returns (address) {
        return approvedTokensList[_index];
    }

    /**
     * @dev Returns the allowance of the approved token for the staking contract.
     * @param _token The address of the approved token.
     * @return The allowance of the approved token for the staking contract.
     */
    function getApprovedTokenAllowance(address _token) public view returns (uint256) {
        return IKonduxERC20(_token).allowance(stakingContract, _token);
    }

    /**
     * @dev Returns the balance of the approved token in the treasury.
     * @param _token The address of the approved token.
     * @return The balance of the approved token in the treasury.
     */
    function getApprovedTokenBalance(address _token) public view returns (uint256) {
        return IKonduxERC20(_token).balanceOf(address(this));
    }

    /**
     * @dev Returns the Ether balance of the treasury.
     * @return The Ether balance of the treasury.
     */
    function getEtherBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Returns the address of the staking contract.
     * @return The address of the staking contract.
     */
    function getStakingContract() public view returns (address) {
        return stakingContract;
    }

    /**
     * @dev Returns the allowance of the token for the staking contract.
     * @param _token The address of the token.
     * @return The allowance of the token for the staking contract.
     */
    function getStakingContractAllowance(address _token) public view returns (uint256) {
        return IKonduxERC20(_token).allowance(address(this), stakingContract);
    }

    /**
     * @dev Returns the balance of the token in the staking contract.
     * @param _token The address of the token.
     * @return The balance of the token in the staking contract.
     */
    function getStakingContractBalance(address _token) public view returns (uint256) {
        return IKonduxERC20(_token).balanceOf(stakingContract);
    }

    /**
     * @dev Returns the Ether balance of the staking contract.
     * @return The Ether balance of the staking contract.
     */
    function getStakingContractEtherBalance() public view returns (uint256) {
        return stakingContract.balance;
    }

}


