// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/*\
Created by SolidityX for Decision Game
Telegram: @solidityX
\*/

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function burn(uint256 amount) external; 
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
}

library EnumerableSet {

    struct Set {
        bytes32[] _values;
        mapping(bytes32 => uint256) _indexes;
    }

    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    struct Bytes32Set {
        Set _inner;
    }

    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }


    struct AddressSet {
        Set _inner;
    }

    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;
        assembly {
            result := store
        }

        return result;
    }
}
library SafeMath {

    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

interface AutomationCompatibleInterface {
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);
  function performUpkeep(bytes calldata performData) external;
}

contract AutomationBase {
  error OnlySimulatedBackend();

  function preventExecution() internal view {
    if (tx.origin != address(0)) {
      revert OnlySimulatedBackend();
    }
  }
  modifier cannotExecute() {
    preventExecution();
    _;
  }
}

abstract contract AutomationCompatible is AutomationBase, AutomationCompatibleInterface {}



contract Staking is AutomationCompatible{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint;

    IERC20 private depToken;
    IERC20 private rewToken;
    EnumerableSet.AddressSet private stakeholders;

    struct Stake {
        uint staked;
        uint shares;
        uint unlock;
    }

    address public owner;
    address public registry;
    uint private totalStakes;
    uint private totalShares;
    uint private minForExecution = 3;
    uint private maxForExecution = 9;
    bool private initialized;

    mapping(address => Stake) private stakeholderToStake;
    mapping(uint => uint) private timePeriods;

    modifier onlyOwner() {
        require(msg.sender == owner, "caller not owner");
        _;
    }


    constructor(address _depToken, address _rewToken, address _registry, uint[] memory _timePeriods) {
        depToken = IERC20(_depToken);
        rewToken = IERC20(_rewToken);
        registry = _registry;
        owner = msg.sender;
        for(uint i; i < _timePeriods.length; i++) {
            timePeriods[i] = _timePeriods[i];
        }
    }

    event StakeAdded(address indexed stakeholder, uint amount, uint shares, uint timestamp);
    event StakeRemoved(address indexed stakeholder, uint amount, uint shares, uint reward, uint timestamp);


/*//////////////////////////////////////////////‾‾‾‾‾‾‾‾‾‾\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*\
///////////////////////////////////////////////executeables\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
\*\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\____________/////////////////////////////////////////////*/

    /*\
    initialize all values
    amount will be locked forever
    \*/
    function initialize(uint _amount, uint _p) external onlyOwner {
        require(!initialized, "already initialized!");
        require(depToken.transferFrom(msg.sender, address(this), _amount), "transfer failed!");
        require(timePeriods[_p] > 0, "invalid time period!");


        stakeholderToStake[address(0x0)] = Stake({
            staked: _amount,
            shares: _amount,
            unlock: 0
        });
        totalStakes = _amount;
        totalShares = _amount;
        initialized = true;
        owner = address(0x0);
        emit StakeAdded(address(0x0), _amount, _amount, block.timestamp);
    }

    /*\
    stake tokens
    \*/
    function deposit(uint _amount, uint _p) external returns(bool) {
        require(initialized, "not initialized!");
        require(stakeholderToStake[msg.sender].staked == 0, "already deposited!");
        require(timePeriods[_p] > 0, "invalid time period!");
        require(_amount > 0, "amount too small!");

        uint tbal = depToken.balanceOf(address(this)).add(rewToken.balanceOf(address(this)));
        uint shares = _amount.mul(totalShares).div(tbal);
        require(depToken.transferFrom(msg.sender, address(this), _amount), "transfer failed!");

        stakeholders.add(msg.sender);
        stakeholderToStake[msg.sender] = Stake({
            staked: _amount,
            shares: shares,
            unlock: block.timestamp.add(timePeriods[_p])
        });
        totalStakes = totalStakes.add(_amount);
        totalShares += shares;
        emit StakeAdded(msg.sender, _amount, shares, block.timestamp);
        return true;
    }

    /*\
    withdraw function if in emergency state (no rewards)
    \*/
    function emergencyWithdraw() external returns(bool) {
        uint stake = stakeholderToStake[msg.sender].staked;
        uint shares = stakeholderToStake[msg.sender].shares;

        stakeholderToStake[msg.sender] = Stake({
            staked: 0,
            shares: 0,
            unlock: 0
        });
        totalShares = totalShares.sub(shares);
        totalStakes = totalStakes.sub(stake);

        require(depToken.transfer(msg.sender, stake), "initial transfer failed!");

        stakeholders.remove(msg.sender);
        return true;
    }

    /*\
    remove staked tokens
    \*/
    function withdraw() external returns(bool){
        _withdraw(msg.sender);
        return true;
    }

    function _withdraw(address _account) internal {
        require(block.timestamp >= stakeholderToStake[_account].unlock, "stake still locked!");
        require(stakeholderToStake[_account].staked > 0, "not staked!");
        uint rewards = rewardOf(_account);
        uint stake = stakeholderToStake[_account].staked;
        uint shares = stakeholderToStake[_account].shares;

        stakeholderToStake[_account] = Stake({
            staked: 0,
            shares: 0,
            unlock: 0
        });
        totalShares = totalShares.sub(shares);
        totalStakes = totalStakes.sub(stake);

        require(depToken.transfer(_account, stake), "initial transfer failed!");
        require(rewToken.transfer(_account, rewards), "reward transfer failed!");

        stakeholders.remove(_account);

        emit StakeRemoved(_account, stake, shares, rewards, block.timestamp);
    }

    /*\
    executed by chainlink automation
    withdraws all withdrawable stakes in performData
    \*/
    function performUpkeep(bytes calldata performData) external override {
        require(msg.sender == registry, "not registry!");
        (address[] memory withdrawable) = abi.decode(performData, (address[]));
        for(uint i; i < withdrawable.length; i++) {
            _withdraw(withdrawable[i]);
        }
    }

    /*\
    called by chainlink automation
    returns all withdrawable stakes
    \*/
    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
        address[] memory withdrawableFULL = new address[](getTotalStakeholders());
        uint count;
        for(uint i; i < withdrawableFULL.length; i++) {
            if(block.timestamp >= stakeholderToStake[stakeholders.at(i)].unlock) {
                withdrawableFULL[count] = stakeholders.at(i);
                count++;
            }
            if(count >= maxForExecution)
                break;
        }
        address[] memory withdrawable = new address[](count);
        for(uint i; i < withdrawable.length; i++) {
            withdrawable[i] = withdrawableFULL[i];
        }
        performData = abi.encode(withdrawable);
        if(count >= minForExecution)
            upkeepNeeded = true;
    }


/*//////////////////////////////////////////////‾‾‾‾‾‾‾‾‾‾‾\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*\
///////////////////////////////////////////////viewable/misc\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
\*\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_____________/////////////////////////////////////////////*/


    /*\
    ratio of token/share
    \*/
    function getRatio() public view returns(uint) {
        uint tbal = depToken.balanceOf(address(this)).add(rewToken.balanceOf(address(this)));
        return tbal.mul(1e18).div(totalShares);
    }

    /*\
    get token stake of user
    \*/
    function stakeOf(address stakeholder) public view returns (uint) {
        return stakeholderToStake[stakeholder].staked;
    }

    /*\
    get shares of user
    \*/
    function sharesOf(address stakeholder) public view returns (uint) {
        return stakeholderToStake[stakeholder].shares;
    }

    /*\
    get total amount of tokens staked
    \*/
    function getTotalStakes() external view returns (uint) {
        return totalStakes;
    }

    /*\
    get total amount of shares
    \*/ 
    function getTotalShares() external view returns (uint) {
        return totalShares;
    }

    /*\
    get total current rewards
    \*/
    function getCurrentRewards() external view returns (uint) {
        return rewToken.balanceOf(address(this));
    }

    /*\
    get list of all stakers
    \*/
    function getTotalStakeholders() public view returns (uint) {
        return stakeholders.length();
    }

    /*\
    get the unix timestamp when the stake of staker unlocks
    \*/
    function getUnlockOf(address staker) external view returns(uint) {
        return stakeholderToStake[staker].unlock;
    }

    /*\
    get rewards that user received
    \*/
    function rewardOf(address stakeholder) public view returns (uint) {
        uint stakeholderStake = stakeOf(stakeholder);
        uint stakeholderShares = sharesOf(stakeholder);

        if (stakeholderShares == 0) {
            return 0;
        }

        uint stakedRatio = stakeholderStake.mul(1e18).div(stakeholderShares);
        uint currentRatio = getRatio();

        if (currentRatio <= stakedRatio) {
            return 0;
        }

        uint rewards = stakeholderShares.mul(currentRatio.sub(stakedRatio)).div(1e18);
        return rewards;
    }
}