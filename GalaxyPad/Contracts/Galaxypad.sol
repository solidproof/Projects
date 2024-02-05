// SPDX-License-Identifier: MIT

/*

░██████╗░░█████╗░██╗░░░░░░█████╗░██╗░░██╗██╗░░░██╗██████╗░░█████╗░██████╗░
██╔════╝░██╔══██╗██║░░░░░██╔══██╗╚██╗██╔╝╚██╗░██╔╝██╔══██╗██╔══██╗██╔══██╗
██║░░██╗░███████║██║░░░░░███████║░╚███╔╝░░╚████╔╝░██████╔╝███████║██║░░██║
██║░░╚██╗██╔══██║██║░░░░░██╔══██║░██╔██╗░░░╚██╔╝░░██╔═══╝░██╔══██║██║░░██║
╚██████╔╝██║░░██║███████╗██║░░██║██╔╝╚██╗░░░██║░░░██║░░░░░██║░░██║██████╔╝
░╚═════╝░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░░░░╚═╝░░╚═╝╚═════╝░

    Website: https://galaxypad.io
    Twitter: https://twitter.com/galaxypadtoken
    Telegram: https://t.me/galaxypadofficial

    This token has a 1% burn fee on sell.

    More information: Read Whitepaper on https://docs.galaxypad.io

*/

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract GalaxyPad is ERC20, Ownable {
    address private pair;
    address public uniswapV2Factory;
    address public uniswapV2Pair;
    uint256 public burnFee; // Tx fee of tokens in percentage of transaction. Example: 100 = 1%, 175 = 1.75%, 200 = 2% etc.
    mapping(address => bool) public feeExemption;
    mapping(address => bool) public isBlacklisted;

    bool public feeEnabled = true;

    event BurnFeeUpdated(uint256 oldFee, uint256 newFee);

    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor(
        address _uniswapV2Factory,
        address _pair
    )
        ERC20("GalaxyPad", "GXPAD")
    {
        require(_uniswapV2Factory != address(0), "GalaxyPad::Uniswap factory address cannot be zero.");
        require(_pair != address(0), "GalaxyPad::Pair address cannot be zero.");
        // testnet
        uniswapV2Factory = _uniswapV2Factory;
        pair = _pair;

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Factory).createPair(
            address(this),
            pair
        );

        _mint(msg.sender, 100000000 * (10**18));
        address burnAddress = 0x000000000000000000000000000000000000dEaD;

        // Fees
        burnFee = 100; // 1%

        // feeExemption
        feeExemption[burnAddress] = true;
        feeExemption[msg.sender] = true;
    }

    /**
     * @dev Function to set new burn fee. Only owner is allowed to change the
     * burn fee below 10%.
     */
    function setBurnFee(uint256 _fee)
        external
        onlyOwner
    {
        require(_fee <= 1000, "GalaxyPad::Fee must be lower than 10%");
        uint256 oldBurnFee = burnFee;
        burnFee = _fee;
        emit BurnFeeUpdated(oldBurnFee, _fee);
    }

    /**
     * @dev Function to enable or disable fee burn. Only owner is allowed to
     * enable/disable it.
     */
    function setFeeEnabled(bool _feeEnabled)
        external
        onlyOwner
    {
        feeEnabled = _feeEnabled;
    }

    /**
     * @dev Function to set a new paid address. Only owner is allowed to set a new
     * pair address it.
     */
    function setPairAddress(address _pairAddress)
        external
        onlyOwner
    {
        require(_pairAddress != address(0), "GalaxyPad::Pair address cannot be zero");
        uniswapV2Pair = _pairAddress;
    }

    /**
     * @dev Function to exempt an address from paying fees. Only owner is allowed
     * to set new exempt address.
     */
    function exemptFromFee(
        address _address,
        bool _exempted
    )
        external
        onlyOwner
    {
        feeExemption[_address] = _exempted;
    }

    /**
     * @dev Function to blacklist an address. Blacklisted addresses are not allowed to
     * transfer any tokens anymore. See _checkTransfer function for more information.
     * Only owner is allowed to set new blacklisted address.
     */
    function setBlacklistAddress(
        address _address,
        bool _blacklisted
    )
        external
        onlyOwner
    {
        isBlacklisted[_address] = _blacklisted;
    }

    /**
     * @dev Function to transfer tokens to another address.
     */
    function transfer(
        address to,
        uint256 amount
    )
        public
        override(ERC20)
        returns (bool)
    {
        return super.transfer(to, _checkTransfer(_msgSender(), to, amount));
    }

    /**
     * @dev Function to transfer tokens from a different address to another address.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override(ERC20)
        returns (bool)
    {
        return super.transferFrom(from, to, _checkTransfer(from, to, amount));
    }

    /**
     * @dev Function to check for blacklisted addresses and burning tokens as fee.
     */
    function _checkTransfer(
        address _sender,
        address _receiver,
        uint256 _amount
    )
        internal
        returns (uint256)
    {
        // Check Blacklist
        require(!isBlacklisted[_sender], "GalaxyPad::The sender address is Blacklisted.");
        require(!isBlacklisted[_receiver],"GalaxyPad::The receiver address is Blacklisted.");

        // Check if pair is created
        if (_receiver == uniswapV2Pair) {
            // Check if transaction is a sell and fees are activated/exempted
            // Check Fee
            if (feeEnabled && !feeExemption[_sender]) {
                // Check Fee
                uint256 feeAmount = (_amount * burnFee) / 10000;
                _amount -= feeAmount;
                _burn(_sender, feeAmount);
                return _amount;
            }
        }

        return _amount;
    }
}
