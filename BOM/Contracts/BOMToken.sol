// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
    interface LPPrice {
        function getCurrentPrice(address _lppairaddress) external view returns(uint256);
        function getLatestPrice(address _lppairaddress) external view returns(uint256);
        function updatePriceFromLP(address _lppairaddress) external returns(uint256);
        function getDecVal() external view returns(uint256);
    }
    /**
    * @title Pausable
    * @dev Base contract which allows children to implement an emergency stop mechanism.
    */
    contract Pausable is Ownable {
        event Pause();
        event Unpause();

        bool public paused = false;


        /**
        * @dev Modifier to make a function callable only when the contract is not paused.
        */
        modifier whenNotPaused() {
            require(!paused, "Paused");
            _;
        }

        /**
        * @dev Modifier to make a function callable only when the contract is paused.
        */
        modifier whenPaused() {
            require(paused, "Not paused");
            _;
        }

        /**
        * @dev called by the owner to pause, triggers stopped state
        */
        function pause() public whenNotPaused onlyOwner {
            paused = true;
            emit Pause();
        }

        /**
        * @dev called by the owner to unpause, returns to normal state
        */
        function unpause() public whenPaused onlyOwner {
            paused = false;
            emit Unpause();
        }
    }

    contract BlackList is Ownable {

        /////// Getters to allow the same blacklist to be used also by other contracts (including upgraded BOM) ///////
        function getBlackListStatus(address _maker) external view returns (bool) {
            return isBlackListed[_maker];
        }

        mapping (address => bool) public isBlackListed;

        function addBlackList (address _evilUser) public onlyOwner {
            isBlackListed[_evilUser] = true;
            emit AddedBlackList(_evilUser);
        }

        function removeBlackList (address _clearedUser) public onlyOwner {
            isBlackListed[_clearedUser] = false;
            emit RemovedBlackList(_clearedUser);
        }

        event AddedBlackList(address _user);

        event RemovedBlackList(address _user);

    }

    abstract contract IBOM716 is Ownable {

        using SafeMath for uint;

        struct Weight {
            uint pastWeight;
            uint curWeight;
            bool isActive;
        }

        BOMNft public bomnft;

        uint public totalReward;
        uint public redistID;
        uint public decVal;
        uint public distDelayDuration = 3 days;
        uint public lastDistTime;

        mapping(uint => uint) internal nftBalances;
        mapping(uint => Weight) internal weights;
        mapping(address => uint) public BusinessOf;

        // Public functions
        function nftBalanceOf(uint _nftID) external view returns (uint) {
            require(bomnft.ownerOf(_nftID) == msg.sender || msg.sender == owner(), "Not owner");
            return nftBalances[_nftID];
        }
        function getNFTWeights(uint _nftID) external view returns (Weight memory) {
            require(bomnft.ownerOf(_nftID) == msg.sender || msg.sender == owner(), "Not owner");
            Weight memory _wei = weights[_nftID];
            return _wei;
        }
        function getTotalReward() external view returns (uint) {
            return totalReward;
        }

        function changeDistDelay(uint _distDelay) external onlyOwner {
            distDelayDuration = _distDelay;
            emit DistdelayDurationChanged(_distDelay);
        }

        // Abstract functions
        function transferByNFT(uint _nftID, uint _amount) virtual external returns (bool);
        function transferFromByNFT(address _from, uint _nftID, uint _value) virtual external returns (bool);
        function distRewardToNFTHolders() virtual public;
        function withdrawReward(address _to, uint _amount, uint _nftID) virtual external;
        function calcTxnFee(uint _amount) virtual public returns(uint);
        // Test functions

        // Events
        // Called when transferbynft
        event TransferByNFT(address from, uint amount, uint _nftID);
        event DistributeRewardToNFTHolders(uint tot_reward, uint tot_past_weight, uint tot_cur_weight);
        event TransferFee(address from, address to, uint amount, uint fee);
        event LPPriceUpdated(uint);
        event DistdelayDurationChanged(uint);
        event LPstakeUpdated(uint);
        event MarketingAddressUpdated(uint);
    }

    interface BOMNft {
        function ownerOf(uint _nftID) external view returns(address);
        function totalSupply() external view returns(uint);
        function checkIfExistsTokenID(uint _nftID) external view returns(bool);
    }

    contract BOMToken is Context, IERC20, Ownable, IBOM716, BlackList, Pausable {

        using SafeMath for uint256;
        uint public constant MAX_UINT = 2**256 - 1;

        mapping(address => uint256) private _balances;

        mapping(address => mapping(address => uint256)) private _allowances;

        uint256 private _totalSupply;
        uint8 public _decimals;
        string public _symbol;
        string public _name;

        address public lpMasterAddress;
        address public marketingWallet;
        address public teamWallet;
        address public investorWallet1;
        address public investorWallet2;
        address public investorWallet3;
        address public techWallet;

        uint public lpStake = 1000; // 10% by default ! This value can only be decreased
        uint public marketingStake = 1000; // 10% by default ! This value can only be decreased

        LPPrice public lpinfo;
        address public lpAddress = address(0);
        uint public lpprice; // of BOM*USDT LPPair
        uint public lpdecval; // OF BOM*USDT LPPair

        constructor(address _investor1, address _investor2, address _investor3, address _bomnftaddress) {
            require(_investor1 != address(0), "Cannot be zero address");
            require(_investor2 != address(0), "Cannot be zero address");
            require(_investor3 != address(0), "Cannot be zero address");
            require(_bomnftaddress != address(0), "Cannot be zero address");
            _name = 'BOM Token';
            _symbol = 'BOM';
            _decimals = 10;
            decVal = 10 ** _decimals;
            _totalSupply = 10 ** 8 * decVal;
            _balances[msg.sender] = _totalSupply;
            totalReward = 0;

            lpprice = decVal;
            lpdecval = decVal;

            investorWallet1 = _investor1;
            investorWallet2 = _investor2;
            investorWallet3 = _investor3;

            bomnft = BOMNft(_bomnftaddress);

            emit Transfer(address(0), msg.sender, _totalSupply);
        }

        // Set the reward wallets
        function setRewardWalletAddress(address _lpMasterAddress, address _marketingWallet, address _teamWallet, address _techWallet) external onlyOwner {
            require(_lpMasterAddress != address(0), "Cannot be zero address");
            require(_marketingWallet != address(0), "Cannot be zero address");
            require(_teamWallet != address(0), "Cannot be zero address");
            require(_techWallet != address(0), "Cannot be zero address");

            lpMasterAddress = _lpMasterAddress;
            marketingWallet = _marketingWallet;
            teamWallet = _teamWallet;
            techWallet = _techWallet;
        }

        /**
        * @dev Returns the erc token owner.
        */
        function getOwner() external view returns (address) {
            return owner();
        }

        /**
        * @dev Returns the token decimals.
        */
        function decimals() external override view returns (uint8) {
            return _decimals;
        }

        /**
        * @dev Returns the token symbol.
        */
        function symbol() external view returns (string memory) {
            return _symbol;
        }

        /**
        * @dev Returns the token name.
        */
        function name() external view returns (string memory) {
            return _name;
        }

        /**
        * @dev See {ERC20-totalSupply}.
        */
        function totalSupply() external view virtual override returns (uint256) {
            return _totalSupply;
        }

        /**
        * @dev See {ERC20-balanceOf}.
        */
        function balanceOf(address account)
            external
            view
            virtual
            override
            returns (uint256)
        {
            return _balances[account];
        }

        /**
        * @dev See {ERC20-transfer}.
        *
        * Requirements:
        *
        * - `recipient` cannot be the zero address.
        * - the caller must have a balance of at least `amount`.
        */
        function transfer(address recipient, uint256 amount)
            external
            override
            returns (bool)
        {
            require(!isBlackListed[msg.sender], "Blacklisted address");
            // _transfer(_msgSender(), recipient, amount);

            uint txn_fee = calcTxnFee(amount);

            _transfer(msg.sender, recipient, amount, txn_fee, 0);
            emit Transfer(msg.sender, recipient, amount - txn_fee);
            return true;
        }

        // Transferby nft
        function transferByNFT(uint _nftID, uint _value)
            external
            override
            whenNotPaused
            returns(bool) {
            require(!isBlackListed[msg.sender], "Blacklisted address");
            require(bomnft.checkIfExistsTokenID(_nftID), "NFT id doesn't exist");

            uint txn_fee = calcTxnFee(_value);
            uint sendAmount = _value.sub(txn_fee);

            _transfer(msg.sender, bomnft.ownerOf(_nftID), _value, txn_fee, _nftID);

            emit TransferByNFT(msg.sender, sendAmount, _nftID);
            return true;
        }

        function calcTxnFee(uint _value) public override view returns(uint) {
            //assume that the bomToken price is $0.3
            uint usdValue = _value.mul(lpprice).div(lpdecval);
            uint usdFee;
            if (usdValue > 0 && usdValue <= 1 * decVal) usdFee =  usdValue.mul(1400)/10000;
            else if (usdValue <= 10 * decVal) usdFee =  usdValue.mul(400)/10000 + decVal / 10;
            else if (usdValue <= 100 * decVal) usdFee = usdValue.mul(300)/10000 + decVal * 2 / 10;
            else if (usdValue <= 1000 * decVal) usdFee = usdValue.mul(200)/10000 + decVal * 12 / 10;
            else if (usdValue <= 10000 * decVal) usdFee = usdValue.mul(50)/10000 + decVal * 162 / 10;
            else if (usdValue <= 100000 * decVal) usdFee = usdValue.mul(15)/10000 + decVal * 512 / 10;
            else if (usdValue <= 1000000 * decVal) usdFee = usdValue.mul(3)/10000 + decVal * 1712 / 10;
            else usdFee = usdValue/10000 + decVal * 3712 / 10;
            // Convert USD to BOM
            require(usdFee < usdValue, "Fee cannot be greater than the value");
            return usdFee.mul(lpdecval).div(lpprice);
        }

        // Distribute rewards to token holders
        function distRewardToNFTHolders() public override whenNotPaused {
            require(totalReward > 0, "Total Reward cannot be zero");
            require(block.timestamp - lastDistTime > distDelayDuration, "No time to dist");

            uint lpRewardDist = totalReward.mul(lpStake).div(10000);
            uint marketingRewardDist = totalReward.mul(marketingStake).div(10000);
            uint teamRewardDist = totalReward.mul(3).div(100);
            uint techRewardDist = totalReward.mul(3).div(100);
            uint investorRewardDist = totalReward.mul(1).div(100);
            uint burnRewardDist = totalReward.mul(2).div(100);
            uint nftRewardDist = totalReward - lpRewardDist - marketingRewardDist - teamRewardDist - techRewardDist - investorRewardDist * 3 - burnRewardDist;

            uint pastWeightReward = nftRewardDist.mul(10).div(100);
            uint curWeightReward = nftRewardDist.mul(90).div(100);

            _balances[lpMasterAddress] = _balances[lpMasterAddress].add(lpRewardDist);
            _balances[marketingWallet] = _balances[marketingWallet].add(marketingRewardDist);
            _balances[teamWallet] = _balances[teamWallet].add(teamRewardDist);
            _balances[investorWallet1] = _balances[investorWallet1].add(investorRewardDist);
            _balances[investorWallet2] = _balances[investorWallet2].add(investorRewardDist);
            _balances[investorWallet3] = _balances[investorWallet3].add(investorRewardDist);
            _balances[techWallet] = _balances[techWallet].add(techRewardDist);

            redistID = redistID + 1;

            uint _nftTotalSupply = bomnft.totalSupply();
            uint _pastweightsum = 0;
            uint _curweightsum = 0;

            for(uint _index = 1; _index <= _nftTotalSupply; _index++) {
                _pastweightsum = _pastweightsum.add(weights[_index].pastWeight);
                _curweightsum = _curweightsum.add(weights[_index].curWeight);
            }

            if (_pastweightsum == 0)    _balances[marketingWallet] = _balances[marketingWallet].add(pastWeightReward);
            if (_curweightsum == 0)     _balances[marketingWallet] = _balances[marketingWallet].add(curWeightReward);

            for(uint _index = 1; _index <= _nftTotalSupply; _index++) {
                Weight storage _weight = weights[_index];

                if (_pastweightsum > 0) nftBalances[_index] = nftBalances[_index].add(pastWeightReward.mul(_weight.pastWeight).div(_pastweightsum));
                if (_curweightsum > 0) nftBalances[_index] = nftBalances[_index].add(curWeightReward.mul(_weight.curWeight).div(_curweightsum));

                _weight.pastWeight = _weight.pastWeight.add(_weight.curWeight);
                _weight.curWeight = 0;
            }
            lastDistTime = block.timestamp;
            _totalSupply = _totalSupply.sub(burnRewardDist);

            // Update <BOM & USDT> lpprice
            lpprice = lpinfo.updatePriceFromLP(lpAddress);
            lpdecval = lpinfo.getDecVal();

            emit DistributeRewardToNFTHolders(totalReward, _pastweightsum, _curweightsum);
            emit Transfer(address(0), address(0), burnRewardDist);
            totalReward = 0;
        }

        /**
        * @dev See {ERC20-allowance}.
        */
        function allowance(address _owner, address _spender)
            external
            view
            override
            returns (uint256)
        {
            return _allowances[_owner][_spender];
        }

        /**
        * @dev See {ERC20-approve}.
        *
        * Requirements:
        *
        * - `spender` cannot be the zero address.
        */
        function approve(address spender, uint256 amount)
            external
            override
            returns (bool)
        {
            _approve(_msgSender(), spender, amount);
            return true;
        }

        /**
        * @dev See {ERC20-transferFrom}.
        *
        * Emits an {Approval} event indicating the updated allowance. This is not
        * required by the EIP. See the note at the beginning of {ERC20};
        *
        * Requirements:
        * - `sender` and `recipient` cannot be the zero address.
        * - `sender` must have a balance of at least `amount`.
        * - the caller must have allowance for `sender`'s tokens of at least
        * `amount`.
        */
        function transferFrom(
            address sender,
            address recipient,
            uint256 amount
        ) external override returns (bool) {
            require(!isBlackListed[sender], "Blacklisted address");
            uint _allowance = _allowances[sender][msg.sender];

            uint txn_fee = calcTxnFee(amount);

            uint sendAmount = amount.add(txn_fee);

            // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
            // if (_value > _allowance) throw;

            if (_allowance < MAX_UINT) {
                _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount);
            }

            _transfer(sender, recipient, sendAmount, txn_fee, 0);

            emit Transfer(sender, recipient, amount);
            return true;
        }

        // TransferFromByNFT
        function transferFromByNFT(address _from, uint _nftID, uint _value)
            external
            override
            whenNotPaused
            returns (bool) {
            require(!isBlackListed[_from], "Blacklisted address");
            require(bomnft.checkIfExistsTokenID(_nftID), "NFT ID doesn't exist");

            uint _allowance = _allowances[_from][msg.sender];
            address _to = bomnft.ownerOf(_nftID);

            // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
            // if (_value > _allowance) throw;

            if (_allowance < MAX_UINT) {
                _allowances[_from][msg.sender] = _allowance.sub(_value);
            }
            uint sendAmount = _value;

            uint txn_fee = calcTxnFee(_value);
            sendAmount = _value.add(txn_fee);

            _transfer(_from, _to, sendAmount, txn_fee, _nftID);

            emit TransferByNFT(_from, sendAmount, _nftID);
            return true;
        }

        // Withdraw the rewards to specific address
        function withdrawReward(address _to, uint _amount, uint _nftID) external override whenNotPaused {
            require(msg.sender == bomnft.ownerOf(_nftID), "Not owner of nft");
            require(nftBalances[_nftID] >= _amount, "Invalid reward vs withdraw amount");

            _balances[_to] = _balances[_to].add(_amount);
            nftBalances[_nftID] = nftBalances[_nftID].sub(_amount);

        }

        function setBomNFTAddress(address _bomnftaddress) public onlyOwner {
            bomnft = BOMNft(_bomnftaddress);
        }

        /**
        * @dev Atomically increases the allowance granted to `spender` by the caller.
        *
        * This is an alternative to {approve} that can be used as a mitigation for
        * problems described in {ERC20-approve}.
        *
        * Emits an {Approval} event indicating the updated allowance.
        *
        * Requirements:
        *
        * - `spender` cannot be the zero address.
        */
        function increaseAllowance(address spender, uint256 addedValue)
            public
            returns (bool)
        {
            _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
            );
            return true;
        }

        /**
        * @dev Atomically decreases the allowance granted to `spender` by the caller.
        *
        * This is an alternative to {approve} that can be used as a mitigation for
        * problems described in {ERC20-approve}.
        *
        * Emits an {Approval} event indicating the updated allowance.
        *
        * Requirements:
        *
        * - `spender` cannot be the zero address.
        * - `spender` must have allowance for the caller of at least
        * `subtractedValue`.
        */
        function decreaseAllowance(address spender, uint256 subtractedValue)
            public
            returns (bool)
        {
            _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                'ERC20: decreased allowance below zero'
            )
            );
            return true;
        }

        /**
        * @dev Destroys `amount` tokens from the caller.
        *
        * See {ERC20-_burn}.
        */
        function burn(uint256 amount) public virtual {
            _burn(_msgSender(), amount);
        }

        /**
        * @dev Destroys `amount` tokens from `account`, deducting from the caller's
        * allowance.
        *
        * See {ERC20-_burn} and {ERC20-allowance}.
        *
        * Requirements:
        *
        * - the caller must have allowance for ``accounts``'s tokens of at least
        * `amount`.
        */
        function burnFrom(address account, uint256 amount) public virtual {
            uint256 decreasedAllowance =
            _allowances[account][_msgSender()].sub(
                amount,
                'ERC20: burn amount exceeds allowance'
            );

            _approve(account, _msgSender(), decreasedAllowance);
            _burn(account, amount);
        }

        /**
        * @dev Moves tokens `amount` from `sender` to `recipient`.
        *
        * This is internal function is equivalent to {transfer}, and can be used to
        * e.g. implement automatic token fees, slashing mechanisms, etc.
        *
        * Emits a {Transfer} event.
        *
        * Requirements:
        *
        * - `sender` cannot be the zero address.
        * - `recipient` cannot be the zero address.
        * - `sender` must have a balance of at least `amount`.
        */
        function _transfer(
            address sender,
            address recipient,
            uint256 amount,
            uint256 txn_fee,
            uint256 nftID
        ) internal whenNotPaused {
            require(sender != address(0), 'ERC20: transfer from the zero address');
            require(recipient != address(0), 'ERC20: transfer to the zero address');

            _balances[sender] = _balances[sender].sub(
            amount,
            'ERC20: transfer amount exceeds balance'
            );
            totalReward = totalReward.add(txn_fee);
            if (nftID != 0) {
                BusinessOf[sender] = nftID;
                Weight storage _senderWeight = weights[nftID];
                _senderWeight.curWeight += txn_fee;
                nftBalances[nftID] = nftBalances[nftID].add(amount - txn_fee);
            } else {
                uint senderNFT = BusinessOf[sender];
                uint receiveNFT = BusinessOf[recipient];
                Weight storage _senderWeight = weights[senderNFT];
                Weight storage _receiverWeight = weights[receiveNFT];
                _senderWeight.curWeight += txn_fee.div(2);
                _receiverWeight.curWeight += txn_fee.div(2);
                _balances[recipient] = _balances[recipient].add(amount - txn_fee);
            }
            emit TransferFee(sender, recipient, amount, txn_fee);
        }

        /**
        * @dev Destroys `amount` tokens from `account`, reducing the
        * total supply.
        *
        * Emits a {Transfer} event with `to` set to the zero address.
        *
        * Requirements
        *
        * - `account` cannot be the zero address.
        * - `account` must have at least `amount` tokens.
        */
        function _burn(address account, uint256 amount) internal {
            require(account != address(0), 'ERC20: burn from the zero address');

            _balances[account] = _balances[account].sub(
            amount,
            'ERC20: burn amount exceeds balance'
            );
            _totalSupply = _totalSupply.sub(amount);
            emit Transfer(account, address(0), amount);
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
        function _approve(
            address _owner,
            address _spender,
            uint256 amount
        ) internal {
            require(_owner != address(0), "Cannot be zero address");
            require(_spender != address(0), "Cannot be zero address");

            _allowances[_owner][_spender] = amount;
            emit Approval(_owner, _spender, amount);
        }

        function mint(uint256 _mintamount) public onlyOwner {
            uint256 mintamount = _mintamount * decVal;
            _totalSupply += mintamount;
            _balances[msg.sender] += mintamount;

            emit Transfer(address(0), msg.sender, mintamount);
        }


        function transferInvestorWalletOwnership(address newAddress, uint investorID) external returns(bool) {
            require(newAddress != address(0), "Cannot be zero address");
            if (investorID == 1) {
                require(msg.sender == investorWallet1, "Not proper address");
                investorWallet1 = newAddress;
                return true;
            }
            else if (investorID == 2) {
                require(msg.sender == investorWallet2, "Not proper address");
                investorWallet2 = newAddress;
                return true;
            }
            else if (investorID == 3) {
                require(msg.sender == investorWallet3, "Not proper address");
                investorWallet2 = newAddress;
                return true;
            }

            return false;
        }

        function setLPpairaddress(address _address) external onlyOwner {
            require(_address != address(0), "Cannot be zero address");
            lpAddress = _address;
            fetchLPPrice();
        }

        function setLPPriceInfo(address _address) external onlyOwner {
            require(_address != address(0), "Cannot be zero address");
            lpinfo = LPPrice(_address);
        }

        function fetchLPPrice() public {
            // Update <BOM & USDT> lpprice
            lpprice = lpinfo.getCurrentPrice(lpAddress);
            lpdecval = lpinfo.getDecVal();
            emit LPPriceUpdated(lpprice);
        }

        function setLPStake(uint _lpStake) external onlyOwner {
            require(_lpStake < lpStake, "LPStake value can only be decreased!");
            lpStake = _lpStake;
            emit LPstakeUpdated(_lpStake);
        }
        function setMarketingStake(uint _marketingStake) external onlyOwner {
            require(_marketingStake < marketingStake, "MarketingStake value can only be decreased!");
            marketingStake = _marketingStake;
            emit MarketingAddressUpdated(_marketingStake);
        }
    }