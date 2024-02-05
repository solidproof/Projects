// SPDX-License-Identifier: BSD-3-Clause

pragma solidity = 0.8.19;

import "@openzeppelin/contracts@4.9.0/utils/Address.sol";
import "@openzeppelin/contracts@4.9.0/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts@4.9.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.9.0/token/ERC20/utils/SafeERC20.sol";

/**
* Welcome to Gyrowin,
* Gyrowin is a decentralised cross-chain gaming and defi platform,
* which let's user play lottery and earn interest on their winnings
* through lending available within the platform.
* Users will also be able to borrow token to play lottery with zero liquidation on their collateral.
* Moreover, Gyrowin also introduces the new fun way to stake Gyrowin token in Binance chain
* with multiple rewards sources resulting in higher yield for the participants.
* https://gyro.win
*/
contract Gyrowin {

    string public constant name = "Gyrowin";
    string public constant symbol = "GW";
    uint8 public constant decimals = 18;
    uint256 public constant MAX_TOTAL_SUPPLY = 5 * 10 ** (decimals + 9); // 5 billion Gyrowin

    // totalSupply denotes tokens that have been mined and locked including circulatingSupply
    uint256 private _totalSupply;

    // circulatingSupply denotes tokens that currently exists in circulation
    uint256 public circulatingSupply;

    // notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    // notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event NewOwner(address oldOwner, address newOwner);
    event NewTreasury(address oldTreasury, address NewTreasury);
    /// @notice An event thats emittied when users are able to trade token
    event TradingOpen(uint256 indexed openTime);
    /// @notice An event thats emitted when token are locked and circulating supply in decreased
    event LockInfo(address indexed account, uint256 amount, uint256 lockTime);
    /// @notice An event thats emitted when token are unlocked and circulating supply in increased back again
    event UnlockInfo(address indexed account, uint256 amount, uint256 lockTime);
    event GasPriceLimit(uint256 indexed);
    event Fee(uint256 indexed);

    /// @notice owner of the contract
    /// @dev should be multisig address
    address private _owner;

    address private constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // treasury account
    address private _treasury;

    /// @notice list vesting contract address
    mapping(address => bool) private _vestingCA;

    /// @notice list freeezelock contract address
    mapping(address => bool) private _freezeLockCA;


    /**
     * @notice Construct a new Gyrowin token
    */
    bool private _initialize;
    function initialize(address owner, address pair, address treasury) external {
        require(owner == address(0x05803c32E393765a204e22fCF560421729cbCA42), "GW: !owner");
        require(treasury != address(0), "GW: can't be the zero address");
        require(!_initialize, "GW: initialized");
        _owner = owner;
        _balance[_msgSender()] = MAX_TOTAL_SUPPLY;

        _totalSupply = MAX_TOTAL_SUPPLY;
        circulatingSupply = MAX_TOTAL_SUPPLY;

        /// @notice buy/sell fee 1%
        _fee = 1;
        _gasPriceLimit = 5000000000 wei;
        _swapPair[pair] = true;

        _treasury = treasury;

        _initialize = true;
    }

    receive() payable external {}

    modifier onlyOwner() {
        require(_owner == _msgSender(), "GW: !owner"); _;
    }

    modifier onlyLockCA() {
        require(isFreezeLockCA(_msgSender()) || isVestingCA(_msgSender()), "GW: no lock contract"); _;
    }

    using SafeERC20 for IERC20;

    uint256 public _fee;

    /// @notice store trading start block by getLaunchBlock function
    uint256 private launchBlock;

    /// @notice status of getting launch block
    bool private _getLaunchBlock;

    /// @notice initial gas price limit
    uint256 private _gasPriceLimit;

    /// @notice status of buy/sell fee
    bool private lockedFee;

    /// @notice status of MEV restriction
    bool private releasedMEV;

    /// @notice list token pair contract address
    mapping(address => bool) private _swapPair;

    /// @notice limited gas price for mev
    mapping(address => bool) private _mev;

    /// @notice notice Official record of token balances for each account
    mapping(address => uint256) private _balance;

    /// @notice notice Allowance amounts on behalf of others
    mapping(address => mapping(address => uint256)) private _allowance;

    /// @notice A record of each accounts delegate
    mapping(address => address) public _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;
 

    /// @notice The totalSupply method denotes the current circulating total supply of the tokens including lock
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    
    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(_msgSender(), spender, amount);

        return true;
    }


     /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param owner The address of the account holding the funds
     * @param spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowance[owner][spender];
    }


    // This is an alternative to {approve} that can be used as a mitigation for problems described in {BEP20-approve}.
    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        _approve(_msgSender(), spender, _allowance[_msgSender()][spender] + (addedValue));

        return true;
    }


    // This is an alternative to {approve} that can be used as a mitigation for problems described in {BEP20-approve}.
    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        uint256 currentAllowance = _allowance[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "GW: decreased allowance below zero");

        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

 
     /**
     * @notice Transfer `amount` tokens from `sender` to `recepient'
     * @param recipient The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address recipient, uint256 amount) external returns (bool) {
        require(recipient != address(0), "GW: can't transfer to the zero address");

        _transfer(_msgSender(), recipient, amount);

        return true;
    }


    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param sender The address of the source account
     * @param recipient The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(recipient != address(0), "GW: can't transfer to the zero address");
        require(sender != address(0), "GW: can't transfer from the zero address");
        
        _spendAllowance(sender, _msgSender(), amount);
        _transfer(sender, recipient, amount);

        return true;
    }


    /**
     * @notice Get the number of tokens held by the `account`
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balance[account];
    }


    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {BEP20-_burn}.
     */
    function burn(uint256 amount) external returns (bool) {
        require(_msgSender() != address(0), "GW: burn from the zero address");
        require(_balance[_msgSender()] >= amount, "GW: burn amount exceeds balance");
        
        _burn(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function burnFrom(address account, uint256 amount) external returns (bool) {
        require(account != address(0), "GW: burn from the zero address");
        require(_balance[account] >= amount, "GW: burn amount exceeds balance");

        _spendAllowance(account, _msgSender(), amount); // check for the allowance

        _burn(account, amount);

        return true;
    }


    /**
     * @notice Delegate votes from `_msgSender()` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) public {
        return _delegate(_msgSender(), delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                getChainId(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0),
            "GW::delegateBySig: invalid signature"
        );
        require(
            nonce == nonces[signatory]++,
            "GW::delegateBySig: invalid nonce"
        );
        require(
            block.timestamp <= expiry,
            "GW::delegateBySig: signature expired"
        );
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint32 nCheckpoints = numCheckpoints[account];
        return
            nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "GW::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = _balance[delegator];
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address senderRep, address recepientRep, uint256 amount) internal {
        if (senderRep != recepientRep && amount > 0) {
            if (senderRep != address(0)) {
                uint32 senderRepNum = numCheckpoints[senderRep];
                uint256 senderRepOld = senderRepNum > 0
                    ? checkpoints[senderRep][senderRepNum - 1].votes
                    : 0;
                uint256 senderRepNew = senderRepOld - amount;
                _writeCheckpoint(
                    senderRep,
                    senderRepNum,
                    senderRepOld,
                    senderRepNew
                );
            }

            if (recepientRep != address(0)) {
                uint32 recepientRepNum = numCheckpoints[recepientRep];
                uint256 recepientRepOld = recepientRepNum > 0
                    ? checkpoints[recepientRep][recepientRepNum - 1].votes
                    : 0;
                uint256 recepientRepNew = recepientRepOld + amount;
                _writeCheckpoint(
                    recepientRep,
                    recepientRepNum,
                    recepientRepOld,
                    recepientRepNew
                );
            }
        }
    }

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
        uint32 blockNumber = safe32(
            block.number,
            "GW::_writeCheckpoint: block number exceeds 32 bits"
        );

        if (
            nCheckpoints > 0 &&
            checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber
        ) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(
                blockNumber,
                newVotes
            );
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }


    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "GW: can't approve to the zero address");
        require(spender != address(0), "GW: can't approve to the zero address");

        _allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    /**
     * the following features added for standard erc20 _transfer function:
     * check either swap or wallet transfer
     * added buy/sell fee if tranfer is swap
     * the fee goes to treasury account
     * first 4 block numbers has gas price limt after _getLaunchBlock is true
     * and then gas limit for only mev if sender/receipient is in _mev variable
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(_balance[sender] >= amount, "GW: balance is insufficient");
        require(recipient != address(this), "GW: can not transfer to gw contract");

        // allow for adding lp
        if (launchBlock == 0 && (_swapPair[sender] || _swapPair[recipient])) {
            require(_owner == sender, "GW: !owner");
            _moveDelegates(_delegates[sender], _delegates[recipient], amount);
            transferToken(sender, recipient, amount); 

        // take fees on buy/sell
        } else if (_fee != 0 && (_swapPair[sender] || _swapPair[recipient])) {
            uint256 taxAmount = amount * _fee / 100;
            amount = amount - taxAmount;

            // tax distribute to Money plant
            transferToken(sender, _treasury, taxAmount);

            // help to protect honest holders from front-running
            if (block.number <= launchBlock + 3 && tx.gasprice > _gasPriceLimit) {
                revert("GW: exceeded gas price");
            } else if (
                (_mev[sender] || _mev[recipient]) && 
                _gasPriceLimit != 0 &&
                _gasPriceLimit < tx.gasprice
                ) {
                revert("GW: exceeded gas price");
            }
            _moveDelegates(_delegates[sender], _delegates[recipient], amount);
            transferToken(sender, recipient, amount); 
        
        // no fees on wallet transfer
        } else {
            _moveDelegates(_delegates[sender], _delegates[recipient], amount);
            transferToken(sender, recipient, amount); 
        }
    }


    ///@notice normal token transfer
    function transferToken(address sender, address recipient, uint256 amount) internal {
        unchecked {
            _balance[sender] -= amount;
            _balance[recipient] += amount;
        }

         emit Transfer(sender, recipient, amount);
    }


    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the dead address.
     *
     */
    function _burn(address account, uint256 amount) internal {
        unchecked {
            _balance[account] -= amount;
            circulatingSupply -= amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, DEAD_ADDRESS, amount);

        if (_totalSupply < MAX_TOTAL_SUPPLY * 40 / 100) {
            revert("GW: total supply should be equal to or greater than 2 billion");
        }
    }


    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }


    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2 ** 32, errorMessage);
        return uint32(n);
    }


    function getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }


    function renounceOwnership(address dead) external onlyOwner() {
        require(dead == address(0), "GW: invalid address");
        _owner = address(0);
    }


    /**
     * @notice change the owner of the contract
     * @dev only callable by the owner
     * @param account new owner address
     */
    function updateOwner(address account) external onlyOwner() {
        require(account != address(0),"GW: invalid owner address");
        _owner = account;

        emit NewOwner(_owner, account);
    }


    /// update treasury account
    /// @dev only callable by the owner
    function updateTreasury(address account) external onlyOwner() {
        require(account != address(0), "GW: can't be zero address");

        _treasury = account;

        emit NewTreasury(_treasury, account);
    }


    /// update freeze contract address
    /// @dev only callable by the owner
    function updateFreezeLockCA(address contractAddr, bool status) external onlyOwner() {
        require(contractAddr != address(0), "GW: can't be zero address");
        require(isContract(contractAddr), "GW: !contract");

        if (status) {
            require(!_freezeLockCA[contractAddr], "GW: already listed");
        }
        _freezeLockCA[contractAddr] = status;
    }

    /// update vesting contract address
    /// @dev only callable by the owner
    function updateVestingCA(address contractAddr, bool status) external onlyOwner() {
        require(contractAddr != address(0), "GW: can't be zero address");
        require(isContract(contractAddr), "GW: !contract");
        
        if (status) {
            require(!_vestingCA[contractAddr], "GW: already listed");
        }
        _vestingCA[contractAddr] = status;
    }


    /// @dev call by the owner modifier
    function isOwner() external view returns (address) {
        return _owner;
    }


    /// @notice check if the address is the treasury account
    function isTreasury() external view returns (address) {
        return _treasury;
    }


    /// @notice check if the address is the vesting contract address
    function isVestingCA(address account) public view returns (bool) {
        return _vestingCA[account];
    }


    /// @notice check if the address is the freezelock contract address
    function isFreezeLockCA(address account) public view returns (bool) {
        return _freezeLockCA[account];
    }


    /**
     * @notice set pair token address
     * @dev only callable by the owner
     * @param account address of the pair
     * @param pair check 
     */
    function setSwapPair(address account, bool pair) external onlyOwner() {
        require(account != address(0), "GW: can't be zero address");
        if (pair) {
            require(!_swapPair[account], "GW: already listed");
        }
        _swapPair[account] = pair;
    }

    /**
     * @notice check if the address is right pair address
     * @param account address of the swap pair
     * @return Account is valid pair or not
     */
    function isSwapPair(address account) external view returns (bool) {
        return _swapPair[account];
    }


    /**
     * @notice set mev to limit the swap gas price
     * @dev this setting is only valid with setGasLimit function and only callable by owner
     * @param account address of the mev
     * @param mev true to set the limit of address swap price
     */
    function setMEV(address[] calldata account, bool mev) external onlyOwner() {
        require(account.length > 0, "GW: empty accounts");
        for (uint256 i = 0; i < account.length; i++) {
            _mev[account[i]] = mev;
        }
    }


    /**
     * @notice set swap gas price limit to prevent mev
     * @dev if gasPriceLimit sets zero then no more limit possible forever with setMEV function
     * and only callable by owner
     * this setting is only valid with setMEV function
     * the minimum gas price is 3gwei
     * @param gasPriceLimit amount of gas limit
     */
    function setGasLimit(uint256 gasPriceLimit) external onlyOwner() {
        require(gasPriceLimit >= 3000000000 wei, "GW: min. gas price limit is 3gwei");
        require(!releasedMEV, "GW: gas price limit renounced with zero");
        _gasPriceLimit = gasPriceLimit;
        if (_gasPriceLimit == 0) {
            // release gas price limit & mev forever
            releasedMEV = true;
        }

        emit GasPriceLimit(_gasPriceLimit);
    }


    /**
     * @notice set fees
     * @dev only callable by the owner
     * @param newFee buy and sell fee for the token
     * - requirements
     * require maximum 1% buy/sell fee
     * require zero buy/sell forever if _fee set to zero
     */
    function setFee(uint256 newFee) public onlyOwner() {
        require(!lockedFee, "GW: fee renounced with zero");
        _fee = newFee;
        if (_fee == 0) {
            // fee to zero forever
            lockedFee = true;
        } else if(_fee > 1) {
            revert("GW: maximum 1% buy/sell fee");
        }

        emit Fee(_fee);
    }


    /**
     * @dev Set when to open trading
     * @dev set block number to check when _getLaunchBlock is true
     * @dev _getLaunchBlock cannot be set false after it started
     */
    function getLaunchBlock(bool status) external onlyOwner() {
        require(!_getLaunchBlock, "GW: not allowed");
        launchBlock = block.number;
        _getLaunchBlock = status;

        emit TradingOpen(block.timestamp);
    }


    // decrease circulating supply by lock 
    function subtractCirculatingSupply(address contractAddr, uint256 amount) external onlyLockCA() {
        require(
            _vestingCA[contractAddr] ||
            _freezeLockCA[contractAddr],
            "GW: invalid contract"
            );
            
        require(amount <= _balance[contractAddr], "GW: amount exceeds balance");
        
        // subtract locked token from circulatingSupply
        circulatingSupply -= amount;

        if (circulatingSupply <= 0) {
            revert("GW: circulating supply can not be zero");
        }

        emit LockInfo(contractAddr, amount, block.timestamp);
    }

    
    // increase circulating supply by unlock    
    function addCirculatingSupply(address contractAddr, uint256 amount) external onlyLockCA() {
        require(
            _vestingCA[contractAddr] ||
            _freezeLockCA[contractAddr],
            "GW: invalid contract"
            );
        require(amount <= _balance[contractAddr], "GW: amount exceeds balance");

        // add unlocked token to circulatingSupply
        circulatingSupply += amount;

        emit UnlockInfo(contractAddr, amount, block.timestamp);
    }


    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal {
        uint256 currentAllowance = this.allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {

            require(currentAllowance >= value, "GW: insufficent allowance");

            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }


    /**
     * @notice rescue BNB sent to the address
     * @param amount to be retrieved from the contract
     * @param to address of the destination account
     * @dev only callable by the owner
     */
    function rescueBNB(uint256 amount, address payable to) external onlyOwner() {
        require(amount > 0, "GW: zero amount");
        require(to != address(0), "GW: can't be zero address");
        require(amount <= address(this).balance, "GW: insufficient funds");
        to.transfer(amount);
    }

    /**
     * @notice rescue BEP20 token sent to the address
     * @param amount to be retrieved for BEP20 contract
     * @param recipient address of the destination account
     * @dev only callable by the owner
     */
    function rescusBEP20Token(address token, address recipient, uint256 amount) external payable onlyOwner() {
        require(amount > 0, "GW: zero amount");
        require(recipient != address(0), "GW: can't be zero address");
        require(token != address(this), "GW: can not claim contract's own tokens");
        require(amount <= IERC20(token).balanceOf(address(this)), "GW: insufficient funds");

        IERC20(token).safeTransfer(recipient, amount);
    }   


    /**
     * @notice check if the address is contract
     * @param contractAddr address of the contract
     * @return check true if contractAddr is a contract
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     * 
     * @dev Among others, `isContract` will return false for the following
     * types of addresses:
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed

     */
    function isContract(address contractAddr) private view returns (bool check) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

        assembly {
            codehash := extcodehash(contractAddr)
        }
        return (codehash != accountHash && codehash != 0x0);
    } 
}