// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./FactoryERC20.sol";
import "./interfaces/ILock.sol";
import "./interfaces/IBridge.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

struct Deposit{
    string brc20_ticker;
    address evm_token;
    uint256 amount;
    address evm_user;
    address evm_lock_address;
    string btc_user;
    string btc_tx;
    bool withdrawn;
}

struct DepositEvent{
    uint256 id;
    DepositType deposit_type;
}

enum DepositType{
    erc20,
    brc20
}
error minBTCConfirmationsRequired();
error unauthorizedNotProvidedAddress();
error alreadyWithdrawn();
error depositEithIdExist();
error TokenNotSupported();
error noERC20Deposit();
error noBRC20Deposit();

contract Bridge is IBridge, AccessControl,ReentrancyGuard {
    using SafeERC20 for IERC20;
    bytes32 public constant ORACLE = keccak256("ORACLE");
    FactoryERC20 public immutable Factory;
    mapping(uint256 =>Deposit) public AllERC20Deposits;
    mapping(uint256 =>Deposit) public AllBRC20Deposits;
    mapping(string=>DepositEvent) public BTCTxEventLink;
    uint256 public BRC20DepositCount  = 0;
    uint256 public ERC20DepositCount  = 0;
    event BridgeToBTC(address indexed owner,uint256 id);
    event BridgeToEVM(string indexed owner,uint256 id);
    event BridgeToEVMComplete(string indexed owner,uint256 id);
    event BridgeToBTCComplete(address indexed owner,uint256 id);
    // revoke 
    constructor(address _Factory,address admin){
        Factory = FactoryERC20(_Factory);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function depositERC20(address token,uint256 amount,string memory _BTCAddress) external nonReentrant(){
        if(!Factory.hasRole(Factory.BRIDGE_TOKEN(),token) || token == address(0)){
            revert TokenNotSupported();
        }
        address lockAddress = Factory.lockAddress(token);
        ERC20DepositCount+=1;
        IERC20(token).safeTransferFrom(msg.sender,lockAddress,amount);
        Deposit memory b = Deposit(
            Factory.brc20(token),
            token,
            amount,
            msg.sender,
            lockAddress,
            _BTCAddress,
            "",
            false
        );
        
        AllERC20Deposits[ERC20DepositCount] = b;
        emit BridgeToBTC(msg.sender,ERC20DepositCount);
    }
    
    function updateCompleteBRC20Exit(uint256 id,string memory btcTX) external onlyRole(ORACLE){
        Deposit storage e = AllERC20Deposits[id];
        if(e.evm_lock_address== address(0)){
            revert noERC20Deposit();
        }
        e.withdrawn = true;
        e.btc_tx =btcTX;
        BTCTxEventLink[btcTX] = DepositEvent(
            id,
            DepositType.erc20
        );
        emit BridgeToBTCComplete(e.evm_user, id);
    }

    function depositBRC20(
        string memory txHash,
        string memory ticker,
        uint256 amount,
        address wallet,
        string memory btcAddress) external onlyRole(ORACLE){   
        address token = Factory.erc20(ticker);
        if(!Factory.hasRole(Factory.BRIDGE_TOKEN(),token) || token == address(0)){
            revert TokenNotSupported();
        }
        BRC20DepositCount+=1;
        Deposit memory b = Deposit(
            ticker,
            token,
            amount,
            wallet,
            Factory.lockAddress(token),
            btcAddress,
            txHash,
            false
        );
        AllBRC20Deposits[BRC20DepositCount] = b;
        
        BTCTxEventLink[txHash]=DepositEvent(
            BRC20DepositCount,
            DepositType.brc20
        );
        emit BridgeToEVM(btcAddress,BRC20DepositCount);
    }
    function withdrawERC20(uint256 id) external nonReentrant{
        Deposit storage b = AllBRC20Deposits[id];
        if(b.evm_token == address(0)){
            revert noBRC20Deposit();
        }
        address lockAddress = Factory.lockAddress(b.evm_token);
        if(b.evm_user != msg.sender){
            revert unauthorizedNotProvidedAddress();
        }
        if(b.withdrawn){
            revert alreadyWithdrawn();
        }
        b.withdrawn = true;
        ILock(lockAddress).withdraw(msg.sender, b.amount);
        emit BridgeToEVMComplete(b.btc_user,id);
    }


    function revokeAdmin() external onlyRole(DEFAULT_ADMIN_ROLE){
        _grantRole(DEFAULT_ADMIN_ROLE, address(0));
    }

    
}