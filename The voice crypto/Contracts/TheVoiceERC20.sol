// SPDX-License-Identifier: MIT

/*

  _______ _       __      __   _           _____                  _
 |__   __| |      \ \    / /  (_)         / ____|                | |
    | |  | |__   __\ \  / /__  _  ___ ___| |     _ __ _   _ _ __ | |_ ___
    | |  | '_ \ / _ \ \/ / _ \| |/ __/ _ \ |    | '__| | | | '_ \| __/ _ \
    | |  | | | |  __/\  / (_) | | (_|  __/ |____| |  | |_| | |_) | || (_) |
    |_|  |_| |_|\___| \/ \___/|_|\___\___|\_____|_|   \__, | .__/ \__\___/
                                                       __/ | |
                                                      |___/|_|

    Website: https://www.thevoicecrypto.org
    Twitter: https://twitter.com/TheVoiceNFT
    Telegram: https://t.me/thevoicecrypto


    This token has a 1% commission on each transaction, it is sent to the treasury wallet to be burned, finance developments or marketing.

    More information: Read Whitepaper on The Voice Crypro website.

*/

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TheVoiceCrypto is ERC20, Ownable {

    address public treasuryAddress;

    uint256 public fee; // Tx fee of tokens in percentage of transaction. Example: 100 = 1%, 175 = 1.75%, 200 = 2% etc.
    uint256 public maxTx; // Max transaction in percentage of total supply. Example: 500 = 0.5%, 1000 = 1% etc.
    uint256 public cooldownTime; // Cooldown time in seconds.

    bool public feeEnabled = true;
    bool public maxTxEnabled = true;
    bool public cooldownEnabled = true;

    mapping (address => bool) private feeExemption;
    mapping (address => bool) private maxTxExemption;
    mapping (address => bool) private cooldownExemption;
    mapping (address => uint256) private lastTx;
    mapping (address => bool) private isBlacklisted;

    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor (address _treasuryAddress) ERC20( "TheVoiceCrypto", "TVC") {
        _mint(msg.sender, 100_000_000 * (10 ** uint256(decimals())));

        fee = 100;
        maxTx = 8;
        cooldownTime = 60;

        feeExemption[msg.sender] = true;
        maxTxExemption[msg.sender] = true;
        cooldownExemption[msg.sender] = true;

        treasuryAddress = _treasuryAddress;
        feeExemption[treasuryAddress] = true;

    }

    //Setters
    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 1000, "Fee must be less than 10%");
        fee = _fee;
    }

    function setMaxTxSize(uint256 _maxTx) external onlyOwner {
        require(_maxTx >= 8, "Max transaction limit must be more than 0.08%");
        maxTx = _maxTx;
    }

    function setCooldown(uint256 _cooldownTime) external onlyOwner {
        require(_cooldownTime < 3600, "Cooldown must be less than 3600 seconds");
        cooldownTime = _cooldownTime;
    }

    function setFeeEnabled(bool _feeEnabled) external onlyOwner {
        feeEnabled = _feeEnabled;
    }

    function setMaxTxEnabled(bool _maxTxEnabled) external onlyOwner {
        maxTxEnabled = _maxTxEnabled;
    }

    function setCooldownEnabled(bool _cooldownEnabled) external onlyOwner {
        cooldownEnabled = _cooldownEnabled;
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
        treasuryAddress = _treasuryAddress;
    }

    //Exemptions
    function exemptFromFee(address _address) external onlyOwner{
        feeExemption[_address] = true;
    }

    function exemptFromTxSize(address _address) external onlyOwner{
        maxTxExemption[_address] = true;
    }

    function exemptFromCooldown(address _address) external onlyOwner{
        cooldownExemption[_address] = true;
    }

    //Blacklist
    function setBlacklistAddress(address _address, bool _blacklisted) external onlyOwner{
        isBlacklisted[_address] = _blacklisted;
    }

    //Functions
    function transfer(address to, uint256 amount) public override returns (bool) {
        return super.transfer(to, _checkTransfer(msg.sender, to, amount));
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        return super.transferFrom(from, to, _checkTransfer(from, to, amount));
    }

    function _checkTransfer(address _from, address _to, uint256 _amount) internal returns (uint256) {
        //Check Blacklist
        require(!isBlacklisted[_from], "The sender address is Blacklisted.");
        require(!isBlacklisted[_to], "The receiver address is Blacklisted.");

        //Check Cooldown
        if(cooldownEnabled && !cooldownExemption[_from]) {
            require(block.timestamp - lastTx[_from] > cooldownTime, "You are on cooldown, please wait 60 seconds.");
            lastTx[_from] = block.timestamp;
        }

        //Check Tx size
        if(maxTxEnabled && !maxTxExemption[_from]) {
            require(_amount <= maxTx * totalSupply() / 100000, "Transaction amount reaches max tx size.");
        }

        //Check Fee
        if(feeEnabled && !feeExemption[_from]) {
            uint256 feeAmount = _amount * fee / 10000;
            _amount -= feeAmount;
            _sendFeeToTreasury(feeAmount);
            return _amount;
        }else{
            return _amount;
        }
    }

    function _sendFeeToTreasury(uint256 _amount) internal returns (bool) {
        _transfer(_msgSender(), treasuryAddress, _amount);
        return true;
    }

}