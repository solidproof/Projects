/*

██╗     ███████╗███╗   ██╗██████╗ ██████╗     ███╗   ██╗███████╗████████╗██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗
██║     ██╔════╝████╗  ██║██╔══██╗██╔══██╗    ████╗  ██║██╔════╝╚══██╔══╝██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝
██║     █████╗  ██╔██╗ ██║██║  ██║██████╔╝    ██╔██╗ ██║█████╗     ██║   ██║ █╗ ██║██║   ██║██████╔╝█████╔╝ 
██║     ██╔══╝  ██║╚██╗██║██║  ██║██╔══██╗    ██║╚██╗██║██╔══╝     ██║   ██║███╗██║██║   ██║██╔══██╗██╔═██╗ 
███████╗███████╗██║ ╚████║██████╔╝██║  ██║    ██║ ╚████║███████╗   ██║   ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗
╚══════╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝    ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝

Lendr Network is a decentralized governance-free lending protocol offering 0% interest defi loans on real world assets such as:

- LendrUSD: An Inflation Proof Stablecoin
- LendrGold: An On-Chain Gold Stablecoin
- LendrRE: A U.S. Real Estate Stablecoin

The LNDR token can be staked to collect rewards from the Lendr protocol.
learn more at: https://lendr.network

*/                                                                                  

// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/CheckContract.sol";
import "../Dependencies/SafeMath.sol";
import "../Interfaces/ILQTYToken.sol";
// import "../Interfaces/ILockupContractFactory.sol";
import "../Dependencies/console.sol";

/*
* Based upon OpenZeppelin's ERC20 contract:
* https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol
*  
* and their EIP2612 (ERC20Permit / ERC712) functionality:
* https://github.com/OpenZeppelin/openzeppelin-contracts/blob/53516bc555a454862470e7860a9b5254db4d00f5/contracts/token/ERC20/ERC20Permit.sol
* 
*
*  --- Functionality added specific to the LQTYToken ---
* 
* 1) Transfer protection: blacklist of addresses that are invalid recipients (i.e. core Lendr contracts) in external 
* transfer() and transferFrom() calls. The purpose is to protect users from losing tokens by mistakenly sending LQTY directly to a Lendr
* core contract, when they should rather call the right function.
*
* 2) sendToLQTYStaking(): callable only by Lendr core contracts, which move LQTY tokens from user -> LQTYStaking contract.
*
* 3) Supply hard-capped at 100 million
*
* 4) CommunityIssuance and LockupContractFactory addresses are set at deployment
*
* 5) The bug bounties / hackathons allocation is minted at deployment to an EOA

* 6) Tokens are minted at deployment to the CommunityIssuance contract
*
* 7) The LP rewards allocation is minted at deployent to a Staking contract
*
* 8) Tokens are minted at deployment to the Lendr multisig
*
*/

contract LQTYToken is CheckContract, ILQTYToken {
    using SafeMath for uint256;

    // --- ERC20 Data ---

    string constant internal _NAME = "Lendr";
    string constant internal _SYMBOL = "LNDR";
    string constant internal _VERSION = "1";
    uint8 constant internal  _DECIMALS = 18;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint private _totalSupply;

    // --- EIP 2612 Data ---

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TYPE_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;
    
    mapping (address => uint256) private _nonces;

    // --- LQTYToken specific data ---

    uint public constant ONE_YEAR_IN_SECONDS = 31536000;  // 60 * 60 * 24 * 365

    // uint for use with SafeMath
    uint internal _1_MILLION = 1e24;    // 1e6 * 1e18 = 1e24

    uint internal immutable deploymentStartTime;
    address public immutable multisigAddress;

    address public immutable communityIssuanceAddress;
    address public immutable lqtyStakingAddress;

    // enabling unipool - NathajiM + magicpalmtree.eth
    uint internal immutable lpRewardsEntitlement;

    // ILockupContractFactory public immutable lockupContractFactory;

    // --- Events ---

    // event CommunityIssuanceAddressSet(address _communityIssuanceAddress);
    // event LQTYStakingAddressSet(address _lqtyStakingAddress);

    // --- Functions ---
    constructor
    (
        address _communityIssuanceAddress, // USDL Staking rewards
        address _lqtyStakingAddress,
        address _bountyAddress, // Bug bounties / hackathons
        address _lpRewardsAddress, // LP staking rewards
        address _multisigAddress // Lendr Core multisig
    ) 
        public 
    {
        checkContract(_communityIssuanceAddress);
        checkContract(_lqtyStakingAddress);
        // checkContract(_lockupFactoryAddress);

        multisigAddress = _multisigAddress;
        deploymentStartTime  = block.timestamp;
        
        communityIssuanceAddress = _communityIssuanceAddress;
        lqtyStakingAddress = _lqtyStakingAddress;
        // lockupContractFactory = ILockupContractFactory(_lockupFactoryAddress);

        bytes32 hashedName = keccak256(bytes(_NAME));
        bytes32 hashedVersion = keccak256(bytes(_VERSION));

        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = _chainID();
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(_TYPE_HASH, hashedName, hashedVersion);
        
        // --- Initial LQTY allocations ---
     
        uint bountyEntitlement = _1_MILLION.mul(145).div(100); // Allocate 1.45 million to bug bounties / hackathons
        _mint(_bountyAddress, bountyEntitlement);

        // enabling unipool - NathajiM + magicpalmtree.eth
        uint _lpRewardsEntitlement = _1_MILLION.mul(9054).div(10000);  // Allocate 905.4k to LP rewards (0.9054 million)
        lpRewardsEntitlement = _lpRewardsEntitlement;
        _mint(_lpRewardsAddress, _lpRewardsEntitlement);

        uint depositorsAndFrontEndsEntitlement = _1_MILLION.mul(3018).div(100); // Allocate (30.18 - 0.9054) million to community staking rewards under the algorithmic issuance schedule
        depositorsAndFrontEndsEntitlement = depositorsAndFrontEndsEntitlement.sub(_lpRewardsEntitlement); // unipool funds come from the same allocation. 30.18 - 0.9054 = 29.2746
        _mint(_communityIssuanceAddress, depositorsAndFrontEndsEntitlement); //30.18 - 0.9054 = 29.2746

        // Presale tokens will be in the multisig address, to be distributed manually
        // uint presaleEntitlement = _1_MILLION.mul(3018).div(100); // Allocate 30.18 million to presale/initial liquidity
        // _mint(_presaleAddress, presaleEntitlement);

        // Social impact tokens will be in the multisig address, to be distributed manually
        // uint socialImpactEntitlement = _1_MILLION.mul(1).div(2); // Allocate 0.5 million to social impact fund
        // _mint(_socialImpactAddress, socialImpactEntitlement);

        // CEX listing tokens will be in the multisig address, to be distributed manually
        // uint cexListingEntitlement = _1_MILLION.mul(414).div(100); // Allocate 4.14 million to CEX listing fund
        // _mint(_cexListingAddress, cexListingEntitlement);

        // Team vesting tokens will be in the multisig address, to be distributed manually
        // uint teamVestingEntitlement = _1_MILLION.mul(2738).div(100); // Allocate 27.38 million to team vesting fund
        // _mint(_teamVestingAddress, teamVestingEntitlement);
        
        // Allocate the remainder to the LNDR Core Multisig: (100 - 1.45 - 0.9054 - 29.2746 - 30.18 - 0.5 - 4.14 - 27.38) = 6.17 million
        uint multisigEntitlement = _1_MILLION.mul(100) 
            .sub(bountyEntitlement)
            .sub(depositorsAndFrontEndsEntitlement)
            .sub(_lpRewardsEntitlement); // enabling unipool - NathajiM + magicpalmtree.eth
            //.sub(presaleEntitlement)
            //.sub(socialImpactEntitlement)
            //.sub(cexListingEntitlement)
            //.sub(teamVestingEntitlement); 
        _mint(_multisigAddress, multisigEntitlement);

        // no need for renounceOwnership() because this contract is not Ownable 
        // (does not import the ownership functionality, no functions use onlyOwner modifier).
        // the mint() function is internal only, meaning it can never be used by anyone besides at launch
    }

    // --- External functions ---

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    // enabling unipool - NathajiM +  magicpalmtree.eth
    function getLpRewardsEntitlement() external view override returns (uint256) {
        return lpRewardsEntitlement;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        // Restrict the multisig's transfers in first year
        //if (_callerIsMultisig() && _isFirstYear()) {
            // _requireRecipientIsRegisteredLC(recipient); //no LC in USDL
        //}

        _requireValidRecipient(recipient);

        // Otherwise, standard transfer functionality
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        //if (_isFirstYear()) { _requireCallerIsNotMultisig(); }

        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        //if (_isFirstYear()) { _requireSenderIsNotMultisig(sender); }
        
        _requireValidRecipient(recipient);

        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external override returns (bool) {
        //if (_isFirstYear()) { _requireCallerIsNotMultisig(); }
        
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external override returns (bool) {
        //if (_isFirstYear()) { _requireCallerIsNotMultisig(); }
        
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function sendToLQTYStaking(address _sender, uint256 _amount) external override {
        _requireCallerIsLQTYStaking();
        //if (_isFirstYear()) { _requireSenderIsNotMultisig(_sender); }  // Prevent the multisig from staking LQTY - Not needed for USDL
        _transfer(_sender, lqtyStakingAddress, _amount);
    }

    // --- EIP 2612 functionality ---

    function domainSeparator() public view override returns (bytes32) {    
        if (_chainID() == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);
        }
    }

    function permit
    (
        address owner, 
        address spender, 
        uint amount, 
        uint deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) 
        external 
        override 
    {            
        require(deadline >= now, 'LQTY: expired deadline');
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', 
                         domainSeparator(), keccak256(abi.encode(
                         _PERMIT_TYPEHASH, owner, spender, amount, 
                         _nonces[owner]++, deadline))));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner, 'LQTY: invalid signature');
        _approve(owner, spender, amount);
    }

    function nonces(address owner) external view override returns (uint256) { // FOR EIP 2612
        return _nonces[owner];
    }

    // --- Internal operations ---

    function _chainID() private pure returns (uint256 chainID) {
        assembly {
            chainID := chainid()
        }
    }

    function _buildDomainSeparator(bytes32 typeHash, bytes32 name, bytes32 version) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, name, version, _chainID(), address(this)));
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // --- Helper functions ---
    // Not using the built in lock contracts, using pinksale instead
    // function _callerIsMultisig() internal view returns (bool) {
    //     return (msg.sender == multisigAddress);
    // }

    // Not using the built in lock contracts, using pinksale instead
    // function _isFirstYear() internal view returns (bool) {
    //     return (block.timestamp.sub(deploymentStartTime) < ONE_YEAR_IN_SECONDS);
    // }

    // --- 'require' functions ---
    
    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && 
            _recipient != address(this),
            "LQTY: Cannot transfer tokens directly to the LQTY token contract or the zero address"
        );
        require(
            _recipient != communityIssuanceAddress &&
            _recipient != lqtyStakingAddress,
            "LQTY: Cannot transfer tokens directly to the community issuance or staking contract"
        );
    }

    // function _requireRecipientIsRegisteredLC(address _recipient) internal view {
    //     require(lockupContractFactory.isRegisteredLockup(_recipient), 
    //     "LQTYToken: recipient must be a LockupContract registered in the Factory");
    // }

    // function _requireSenderIsNotMultisig(address _sender) internal view {
    //     require(_sender != multisigAddress, "LQTYToken: sender must not be the multisig");
    // }

    // function _requireCallerIsNotMultisig() internal view {
    //     require(!_callerIsMultisig(), "LQTYToken: caller must not be the multisig"); //using pinksale locking instead
    // }

    function _requireCallerIsLQTYStaking() internal view {
         require(msg.sender == lqtyStakingAddress, "LQTYToken: caller must be the LQTYStaking contract");
    }

    // --- Optional functions ---

    function name() external view override returns (string memory) {
        return _NAME;
    }

    function symbol() external view override returns (string memory) {
        return _SYMBOL;
    }

    function decimals() external view override returns (uint8) {
        return _DECIMALS;
    }

    function version() external view override returns (string memory) {
        return _VERSION;
    }

    function permitTypeHash() external view override returns (bytes32) {
        return _PERMIT_TYPEHASH;
    }
}