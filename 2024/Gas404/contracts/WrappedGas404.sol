// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

contract WrappedGas404 is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _minters;

    event AddMinter(address newMinter);
    event RemoveMinter(address oldMinter);

    /// @dev Emitted when `amount` is deposited from `from`.
    event Deposit(address indexed from, uint256 amount);

    /// @dev Emitted when `amount` is withdrawn to `to`.
    event Withdrawal(address indexed to, uint256 amount);

    uint256 public burned;

    IERC20 public Gas404;

    constructor(address _Gas404) ERC20('WrappedGas404', 'WGAS') ERC20Permit('WrappedGas404') Ownable(msg.sender) {
        Gas404 = IERC20(_Gas404);

        address owner_ = msg.sender;
        _minters.add(owner_);
        emit AddMinter(owner_);
    }

    function deposit(uint256 amount) external {
        Gas404.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        Gas404.transfer(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    function burn(uint256 value) public override {
        super.burn(value);
        burned += value;
    }

    function burnFrom(address account, uint256 value) public override {
        super.burnFrom(account, value);
        burned += value;
    }

    function burnForSupply(uint256 amount) external {
        Gas404.transferFrom(msg.sender, address(this), amount);
    }

    /**
     * Minting related functions
     */
    modifier onlyMinter() {
        require(_minters.contains(_msgSender()), 'FORBIDDEN');
        _;
    }

    function minters() external view returns (address[] memory) {
        return _minters.values();
    }

    function addMinter(address _minter) external onlyOwner {
        require(!_minters.contains(_minter), 'DUPLICATE_MINTER');
        _minters.add(_minter);
        emit AddMinter(_minter);
    }

    function removeMinter(address _minter) external onlyOwner {
        require(_minters.contains(_minter), 'INVALID_MINTER');
        _minters.remove(_minter);
        emit RemoveMinter(_minter);
    }

    function mint(address to, uint256 amount) public onlyMinter {
        _mint(to, amount);
    }
}