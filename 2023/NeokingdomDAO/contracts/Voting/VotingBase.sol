// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../ShareholderRegistry/IShareholderRegistry.sol";
import "./IVoting.sol";

abstract contract VotingBase is IVoting {
    event DelegateChanged(
        address indexed delegator,
        address currentDelegate,
        address newDelegate
    );

    event DelegateVotesChanged(
        address indexed account,
        uint256 oldVotingPower,
        uint256 newVotingPower
    );

    IShareholderRegistry internal _shareholderRegistry;
    IERC20Upgradeable internal _token;

    bytes32 internal _contributorRole;

    mapping(address => address) internal _delegates;
    mapping(address => uint256) internal _votingPower;
    mapping(address => uint256) internal _delegators;

    uint256 internal _totalVotingPower;

    // Abstract
    function setToken(IERC20Upgradeable token) external virtual;

    function beforeRemoveContributor(address account) external virtual;

    function afterAddContributor(address account) external virtual;

    function setShareholderRegistry(
        IShareholderRegistry shareholderRegistry
    ) external virtual;

    function canVote(address account) public view virtual returns (bool) {
        return getDelegate(account) != address(0);
    }

    // Public

    /// @dev Returns the account's current delegate
    /// @param account The account whose delegate is requested
    /// @return Account's voting power
    function getDelegate(
        address account
    ) public view virtual returns (address) {
        return _delegates[account];
    }

    /// @dev Returns the amount of valid votes for a given address
    /// @notice An address that is not a contributor, will have always 0 voting power
    /// @notice An address that has not delegated at least itself, will have always 0 voting power
    /// @param account The account whose voting power is requested
    /// @return Account's voting power
    function getVotingPower(
        address account
    ) public view virtual returns (uint256) {
        return _votingPower[account];
    }

    /// @dev Returns the total amount of valid votes
    /// @notice It's the sum of all tokens owned by contributors who has been at least delegated to themselves
    /// @return Total voting power
    function getTotalVotingPower() public view virtual returns (uint256) {
        return _totalVotingPower;
    }

    // Internal

    function _setToken(IERC20Upgradeable token) internal virtual {
        _token = token;
    }

    function _setShareholderRegistry(
        IShareholderRegistry shareholderRegistry
    ) internal virtual {
        _shareholderRegistry = shareholderRegistry;
        _contributorRole = _shareholderRegistry.CONTRIBUTOR_STATUS();
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        _moveVotingPower(getDelegate(from), getDelegate(to), amount);
    }

    function _delegate(
        address delegator,
        address newDelegate
    ) internal virtual {
        address currentDelegate = getDelegate(delegator);
        address newDelegateDelegate = getDelegate(newDelegate);
        uint256 countDelegatorDelegators = _delegators[delegator];

        // pre conditions
        // - participants are contributors
        // (this automatically enforces also that the address is not 0)
        require(
            _shareholderRegistry.isAtLeast(_contributorRole, delegator),
            "Voting: only contributors can delegate."
        );
        require(
            _shareholderRegistry.isAtLeast(_contributorRole, newDelegate),
            "Voting: only contributors can be delegated."
        );
        // - no sub delegation allowed
        require(
            newDelegate == newDelegateDelegate || delegator == newDelegate,
            "Voting: new delegate is not self delegated"
        );
        require(
            countDelegatorDelegators == 0 || delegator == newDelegate,
            "Voting: delegator is already delegated"
        );

        // - first delegate should be self
        require(
            (currentDelegate == address(0) && delegator == newDelegate) ||
                currentDelegate != address(0),
            "Voting: first delegate should be self"
        );

        // - no double delegation
        require(
            newDelegate != currentDelegate,
            "Voting: new delegate equal to old delegate"
        );

        _beforeDelegate(delegator);

        uint256 delegatorBalance = _token.balanceOf(delegator) +
            _shareholderRegistry.balanceOf(delegator);
        _delegates[delegator] = newDelegate;

        if (delegator != newDelegate && newDelegate != address(0)) {
            _delegators[newDelegate]++;
        }

        if (delegator != currentDelegate && currentDelegate != address(0)) {
            _delegators[currentDelegate]--;
        }

        emit DelegateChanged(delegator, currentDelegate, newDelegate);

        _moveVotingPower(currentDelegate, newDelegate, delegatorBalance);
    }

    function _moveVotingPower(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                _beforeMoveVotingPower(from);
                uint256 oldVotingPower = _votingPower[from];
                _votingPower[from] = oldVotingPower - amount;
                emit DelegateVotesChanged(
                    from,
                    oldVotingPower,
                    _votingPower[from]
                );
            } else {
                _beforeUpdateTotalVotingPower();
                _totalVotingPower += amount;
            }

            if (to != address(0)) {
                _beforeMoveVotingPower(to);
                uint256 oldVotingPower = _votingPower[to];
                _votingPower[to] = oldVotingPower + amount;
                emit DelegateVotesChanged(to, oldVotingPower, _votingPower[to]);
            } else {
                _beforeUpdateTotalVotingPower();
                _totalVotingPower -= amount;
            }
        }
    }

    function _beforeRemoveContributor(address account) internal virtual {
        address delegated = getDelegate(account);
        if (delegated == account) {
            _beforeDelegate(account);
        } else {
            _delegate(account, account);
        }

        delete _delegates[account];

        uint256 individualVotingPower = _token.balanceOf(account) +
            _shareholderRegistry.balanceOf(account);
        if (individualVotingPower > 0) {
            _moveVotingPower(account, address(0), individualVotingPower);
        }
    }

    function _afterAddContributor(address account) internal virtual {
        _delegate(account, account);
    }

    function _beforeDelegate(address delegator) internal virtual {}

    function _beforeMoveVotingPower(address account) internal virtual {}

    function _beforeUpdateTotalVotingPower() internal virtual {}
}
