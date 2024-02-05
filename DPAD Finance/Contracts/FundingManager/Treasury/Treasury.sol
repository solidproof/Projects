//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./../../ContractsManager/IContractsManager.sol";
import "./../../RoleManager/IRoleManager.sol";

import "./../../IDODetails/IIDODetailsGetter.sol";
import "./../../IDOFactory/IIDOFactory.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../PancakeSwap/IPancakeV2Router02.sol";
import "../../PancakeSwap/IPancakeV2Factory.sol";

import "./../../Admin/IAdmin.sol";
import "./../../StakingManager/IStakingManager.sol";

contract Treasury {
    using SafeMath for uint;
    IContractsManager contractsManager;

    uint idoId;

    mapping (address => uint) public contributions;
    mapping (address => uint) public claimed;
    mapping (address => uint) public refunded;

    uint public contributed;

    event Contributed(uint idoId, uint amount, address contributor);

    constructor(address _contractsManager, uint _idoId) {
        contractsManager = IContractsManager(_contractsManager);
        idoId = _idoId;
    }

    modifier onlyPresale() {
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetailsGetter _idoDetails = IIDODetailsGetter(_idoFactory.idoIdToIDODetailsContract(idoId));
        require(msg.sender == _idoDetails.preSale(), 'TR:106'); // Treasury: Only presale is allowed
        _;
    }

    modifier onlyAdmin() {
        IRoleManager roleManager = IRoleManager(contractsManager.roleManager());
        require(roleManager.isAdmin(msg.sender), 'TR:101'); // Admin: Only IDO Admin allowed
        _;
    }

    function contribute(address _contributor, uint _amount) onlyPresale public {
        contributions[_contributor] += _amount;
        contributed += _amount;

        emit Contributed(idoId, _amount, _contributor);
    }

    function claim(address _recipient) onlyPresale public {
        require(claimed[_recipient] == 0, 'TR:103'); // Treasury: Already claimed, cannot claim more then once.

        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetailsGetter _idoDetails = IIDODetailsGetter(_idoFactory.idoIdToIDODetailsContract(idoId));

        uint _tokensToTransfer = contributions[_recipient].div(_idoDetails.basicIdoDetails().tokenPrice).mul(10 ** IERC20Metadata(_idoDetails.tokenAddress()).decimals());
        transferTokens(_recipient, _tokensToTransfer);
        claimed[_recipient] = _tokensToTransfer;
    }

    function refund(address _recipient) onlyPresale public {
        require(refunded[_recipient] == 0, 'TR:104'); // Treasury: Already refunded, cannot refund more then once.
        _transferAnyToken(contractsManager.busd(), _recipient, contributions[_recipient]);
        refunded[_recipient] = contributions[_recipient];
    }

    function addToLP(uint _tokenAmount, uint _bnbAmount) onlyPresale public {
        IPancakeV2Router02 pcsRouter = IPancakeV2Router02(contractsManager.pcsRouter());
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetailsGetter _idoDetails = IIDODetailsGetter(_idoFactory.idoIdToIDODetailsContract(idoId));
        // This will automatically create pair if pair is not there
        IERC20(_idoDetails.tokenAddress()).approve(contractsManager.pcsRouter(), _tokenAmount);
        pcsRouter.addLiquidityETH{value: _bnbAmount}(_idoDetails.tokenAddress(), _tokenAmount, 0, 0, _idoDetails.preSale(), block.timestamp);
    }

    function transferDevRewards() onlyPresale public {
        IAdmin _admin = IAdmin(contractsManager.adminContract());
//        transferBNB(contractsManager.developerAddress(), contributed.div(_admin.devRewards())); //to calculate 1%
        _transferAnyToken(contractsManager.busd(), contractsManager.developerAddress(), contributed.mul(_admin.devRewards()).div(10000)); //to calculate 1% divide by 100
    }

    function transferStakingRewards() onlyPresale public {
        IAdmin _admin = IAdmin(contractsManager.adminContract());
//        transferBNB(contractsManager.stakingManager(), contributed.div(_admin.stakingRewards())); //to calculate 2% divide by 50
        IStakingManager _stakingManager = IStakingManager(contractsManager.stakingManager());
        uint stakingRewards = contributed.mul(_admin.stakingRewards()).div(10000); // to calculate 2% divide
        IERC20(contractsManager.busd()).approve(address(_stakingManager), stakingRewards);
        _stakingManager.receiveReward(stakingRewards);
//        _transferAnyToken(contractsManager.busd(), contractsManager.stakingManager(), );
    }

    function transferTokens(address _recipient, uint _amount) internal {
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetailsGetter _idoDetails = IIDODetailsGetter(_idoFactory.idoIdToIDODetailsContract(idoId));

        IERC20 _token = IERC20(_idoDetails.tokenAddress());
        _token.transfer(_recipient, _amount);
    }

    function transferBNB(address _recipient, uint _amount) internal {
        (bool success, ) = payable(_recipient).call{value:_amount}("");
        require(success, "TR:105"); // Treasury: Transfer failed.
    }

    function _transferAnyToken(address _tokenAddress, address _recipient, uint _amount) internal {
        require(IERC20(_tokenAddress).transfer(_recipient, _amount), "TR:102"); // token transfer failed
    }

    function adminTransferToken(address _tokenAddress, address _recipient, uint _amount) public onlyAdmin {
        _transferAnyToken(_tokenAddress, _recipient, _amount);
    }

    function adminTransferBNB(address _recipient, uint _amount) public onlyAdmin {
        transferBNB(_recipient, _amount);
    }
}
