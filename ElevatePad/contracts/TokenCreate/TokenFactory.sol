// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

library AddressUpgradeable {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data)
        internal
        view
        returns (bytes memory)
    {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    modifier initializer() {
        require(
            _initializing || _isConstructor() || !_initialized,
            "Initializable: contract is already initialized"
        );

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {}

    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }

    uint256[50] private __gap;
}

abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    uint256[49] private __gap;
}

interface IStandardToken {
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address owner_,
        address serviceFeeReceiver_,
        uint256 serviceFee_
    ) external payable;

    function transferOwnership(address newOwner) external;
}

interface IBabyToken {
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address owner_,
        address poolFactory_,
        address[4] memory addrs, // reward, router, marketing wallet, dividendTracker, owner
        uint256[3] memory feeSettings, // rewards, liquidity, marketing
        uint256 minimumTokenBalanceForDividends_,
        address serviceFeeReceiver_,
        uint256 serviceFee_
    ) payable external;

    function transferOwnership(address newOwner) external;
}

interface IBuybackBabyToken {
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address rewardToken_,
        address router_,
        address owner_,
        address poolFactory_,
        uint256[5] memory feeSettings_,
        address serviceFeeReceiver_,
        uint256 serviceFee_
    ) payable external;

    function transferOwnership(address newOwner) external;
}

interface ILiquidityGeneratorToken {
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address[3] memory addrs,   // router, charityAddr, marketingAddr
        address owner_,
        address poolFactory_,
        uint256[4] memory feeSettings_,    // taxFee, liquidityFee, charityFee, marketingFee,
        address serviceFeeReceiver_,
        uint256 serviceFee_
    ) payable external;

    function transferOwnership(address newOwner) external;
}

library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            instance := create2(0, ptr, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000
            )
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt)
        internal
        view
        returns (address predicted)
    {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}

contract TokenFactory is OwnableUpgradeable {
    address public _implBaby;
    address public _implBuyback;
    address public _implLiquidity;
    address public _implStandard;
    address public _poolFactory;
    address public _feeReceiver;

    uint256 public _tokenCreateFee;

    mapping (address => bool) private isCreatedByFactory;

    function initialize (
        address implBaby_,
        address implBuyback_,
        address implLiquidity_,
        address implStarndard_,
        address poolFactory_,
        address feeReceiver_
    ) external initializer {
        __Ownable_init();
        _implBaby = implBaby_;
        _implBuyback = implBuyback_;
        _implLiquidity = implLiquidity_;
        _implStandard = implStarndard_;
        _poolFactory = poolFactory_;
        _tokenCreateFee = 0.1 ether;
        _feeReceiver = feeReceiver_;
    }

    receive() external payable {}

    function createBaby (
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address[4] memory addrs, // reward, router, marketing wallet, dividendTracker, owner
        uint256[3] memory feeSettings, // rewards, liquidity, marketing
        uint256 minimumTokenBalanceForDividends_,
        address serviceFeeReceiver_,
        uint256 serviceFee_
    ) external payable{
        require(_implBaby != address(0),"implement address is not set");
        require(serviceFeeReceiver_ == _feeReceiver, "Incorrect feeReceiver address");
        address pair = Clones.clone(_implBaby);
        IBabyToken(pair).initialize{ value: serviceFee_ }(
            name_,
            symbol_,
            totalSupply_,
            msg.sender,
            _poolFactory,
            addrs,
            feeSettings,
            minimumTokenBalanceForDividends_,
            serviceFeeReceiver_,
            serviceFee_
        );
        isCreatedByFactory[pair] = true;
        IBabyToken(pair).transferOwnership(msg.sender);
    }

    function createBuyback (
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address rewardToken_,
        address router_,
        uint256[5] memory feeSettings_,
        address serviceFeeReceiver_,
        uint256 serviceFee_
    ) external payable {
        require(_implBuyback != address(0), "implement address is not set");
        require(serviceFeeReceiver_ == _feeReceiver, "Incorrect feeReceiver address");
        address pair = Clones.clone(_implBuyback);
        IBuybackBabyToken(pair).initialize{ value: serviceFee_ }(
            name_,
            symbol_,
            totalSupply_,
            rewardToken_,
            router_,
            msg.sender,
            _poolFactory,
            feeSettings_,
            serviceFeeReceiver_,
            serviceFee_
        );
        isCreatedByFactory[pair] = true;
        // IBuybackBabyToken(pair).transferOwnership(msg.sender);
    }

    function createLiquidity (
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address[3] memory addrs,   // router, charityAddr, marketingAddr
        uint256[4] memory feeSettings_,    // taxFee, liquidityFee, charityFee, marketingFee,
        address serviceFeeReceiver_,
        uint256 serviceFee_
    ) external payable {
        require(_implLiquidity != address(0), "implement address is not set");
        require(serviceFeeReceiver_ == _feeReceiver, "Incorrect feeReceiver address");
        address pair = Clones.clone(_implLiquidity);
        ILiquidityGeneratorToken(pair).initialize{ value: serviceFee_ }(
            name_,
            symbol_,
            totalSupply_,
            addrs,
            msg.sender,
            _poolFactory,
            feeSettings_,
            serviceFeeReceiver_,
            serviceFee_
        );
        isCreatedByFactory[pair] = true;
        ILiquidityGeneratorToken(pair).transferOwnership(msg.sender);
    }

    function createStandard (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address serviceFeeReceiver_,
        uint256 serviceFee_
    ) external payable {
        require(_implStandard != address(0), "implement address is not set");
        require(serviceFeeReceiver_ == _feeReceiver, "Incorrect feeReceiver address");
        address pair = Clones.clone(_implStandard);
        IStandardToken(pair).initialize{ value: serviceFee_ }(
            name_,
            symbol_,
            decimals_,
            totalSupply_,
            msg.sender,
            serviceFeeReceiver_,
            serviceFee_
        );
        isCreatedByFactory[pair] = true;
        IStandardToken(pair).transferOwnership(msg.sender);
    }

    function IsCreatedTokenByFactory(address _token) external view returns(bool) {
        return isCreatedByFactory[_token];
    }

    function setBabyAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "TokenFactory: zero address");
        _implBaby = _newAddress;
    }

    function setBuybackAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "TokenFactory: zero address");
        _implBuyback = _newAddress;
    }

    function setLiquidityAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "TokenFactory: zero address");
        _implLiquidity = _newAddress;
    }

    function setStandardAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "TokenFactory: zero address");
        _implStandard = _newAddress;
    }

    function setPoolFactoryAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "TokenFactory: zero address");
        _poolFactory = _newAddress;
    }

    function setCreateFee(uint256 _newValue) external onlyOwner {
        _tokenCreateFee = _newValue;
    }

    function setFeeReceiver(address _newAddress) external onlyOwner {
        _feeReceiver = _newAddress;
    }
}