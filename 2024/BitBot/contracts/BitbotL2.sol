// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { IOptimismMintableERC20 } from "./IOptimismMintableERC20.sol";

contract BITBOTL2 is IOptimismMintableERC20, ERC20, Ownable {
    /// @notice Address of the corresponding version of this token on the remote chain.
    address public immutable REMOTE_TOKEN;

    /// @notice Address of the StandardBridge on this network.
    address public immutable BRIDGE;

    address private feeReceiver;
    uint256 public feeRate = 0;

    mapping(address => bool) fromTaxWhitelist;
    mapping(address => bool) toTaxWhitelist;

    /// @notice Emitted whenever tokens are minted for an account.
    /// @param account Address of the account tokens are being minted for.
    /// @param amount  Amount of tokens minted.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted whenever tokens are burned from an account.
    /// @param account Address of the account tokens are being burned from.
    /// @param amount  Amount of tokens burned.
    event Burn(address indexed account, uint256 amount);

    /// @notice A modifier that only allows the bridge to call.
    modifier onlyBridge() {
        require(msg.sender == BRIDGE, "MyCustomL2Token: only bridge can mint and burn");
        _;
    }

    /// @param _bridge      Address of the L2 standard bridge.
    /// @param _remoteToken Address of the corresponding L1 token.
    /// @param _name        ERC20 name.
    /// @param _symbol      ERC20 symbol.
    constructor(
        address _bridge,
        address _remoteToken,
        string memory _name,
        string memory _symbol,
        address _feeReceiver
    ) ERC20(_name, _symbol) {
        REMOTE_TOKEN = _remoteToken;
        BRIDGE = _bridge;
        feeReceiver = _feeReceiver;
    }

    /// @custom:legacy
    /// @notice Legacy getter for REMOTE_TOKEN.
    function remoteToken() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for BRIDGE.
    function bridge() public view returns (address) {
        return BRIDGE;
    }

    /// @notice ERC165 interface check function.
    /// @param _interfaceId Interface ID to check.
    /// @return Whether or not the interface is supported by this contract.
    function supportsInterface(bytes4 _interfaceId) external pure virtual returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the updated OptimismMintableERC20 (this contract).
        bytes4 iface2 = type(IOptimismMintableERC20).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface2;
    }

    /// @notice Allows the StandardBridge on this network to mint tokens.
    /// @param _to     Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function mint(address _to, uint256 _amount) external virtual override(IOptimismMintableERC20) onlyBridge {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    /// @notice Prevents tokens from being withdrawn to L1.
    function burn(
        address internalAccount,
        uint256 _amount
    ) external virtual override(IOptimismMintableERC20) onlyBridge {
        _burn(internalAccount, _amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        bool disableTax = fromTaxWhitelist[_msgSender()] || toTaxWhitelist[recipient] || feeRate == 0;
        uint256 tax = disableTax ? 0 : getTransferTax(amount);
        uint256 amountAfterTax = amount - tax;

        _transfer(_msgSender(), recipient, amountAfterTax);

        if (tax > 0) {
            _transfer(_msgSender(), feeReceiver, tax);
        }

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        bool disableTax = fromTaxWhitelist[from] || toTaxWhitelist[to] || feeRate == 0;
        uint256 tax = disableTax ? 0 : getTransferTax(amount);
        uint256 amountAfterTax = amount - tax;

        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amountAfterTax);

        if (tax > 0) {
            _transfer(from, feeReceiver, tax);
        }

        return true;
    }

    function getTransferTax(uint256 amount) private view returns (uint256) {
        if (feeRate == 0) {
            return 0;
        }

        return (amount * feeRate) / 10000;
    }

    function setFromTaxWhitelist(address account, bool isWhitelisted) public onlyOwner {
        fromTaxWhitelist[account] = isWhitelisted;
    }

    function setToTaxWhitelist(address account, bool isWhitelisted) public onlyOwner {
        toTaxWhitelist[account] = isWhitelisted;
    }

    function getFromTaxWhitelist(address account) public view returns (bool) {
        return fromTaxWhitelist[account];
    }

    function getToTaxWhitelist(address account) public view returns (bool) {
        return toTaxWhitelist[account];
    }

    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        feeReceiver = _feeReceiver;
    }

    function setFeeRate(uint256 _feeRate) public onlyOwner {
        // Max fee 5%
        require(_feeRate <= 500, "Invalid fee rate");
        feeRate = _feeRate;
    }
}