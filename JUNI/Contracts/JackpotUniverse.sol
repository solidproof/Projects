/**
 *Submitted for verification at BscScan.com on 2022-08-30
*/

//                                   @@@@@@@&&##&%
//                            %&&&@@@@@@@@&&&%%&&%%&%&%/*
//                        #%&&@@@@@@@@@@&@@&&&%(&%&&&&/***.,.
//                     .#%&@@@@@@@@@@@@@@&&&&&*/&(%%%%&*#(/,/*.
//                   (#%&@@@@@@@@@@@@&@@&&&&%%%%%##/((/**%#**.*/**
//                  (##%%%%%##(*,,,%&&#,,,,,,,,,,,,,,,,,((##(#,,,(/
//              ,&%%#%%%%..%%%%%#%.*&&#.%%%%#&&..%#%%%%%##./(/.%&%%%#%,,%,,,,,,,
//              .&%%%%%%%.%%%&%%%&,*%%#.%&%%%%%,,%%%%&&%%&%,//,&%&%%%%,,%%%%%&%,.
//              ,&#%#%%&,,%%%&#%#&,*%%(,%%#%#%%,,&#%%%#%#%%&,.,&%&#%#%,,%%#%%&#&,
//              ,&&%#%&&,,%&&&%%%&,*%&/*&&&%#&&,,%#%&&&&%&&&&%,&&&%%#&(,&%#%&&&%,
//             .,&#%&%&&,,&%&&#&&#,*%%*,@&#&&#&,,%&#&&#%,#&&#%&(&&#%&%@,,%&#&&#%,
//     ,,,,,,,,#,&&&#&&&,,#&&&&&#&,*%%,&&&&&#&&,,&#&&&&&**&&&&#&&&&&#&&,,&#&&&&&,
//   ,&&&@&%&&*%*%&&&@&%,,&@&%&&&@&,,,&@&%&&&@&,,&&@&%&&,.,,&&&@&#&&&@&,,&&@&#&&,.
//   ,%&&@@@%&&&@@%&&@@,.(,&@@%&&&@@%&&&@@%&&,***&&&@@&&,.((.&&&@@&&&&@,,&&&@@%&,.
//    *@&@&@@@&@@@@@&,..//*#,,(&%@&@@@&@&@,,.*#*,&%&&@@@,.///,%@@@@@&@&,,@&@&@@@%,
//      ,,,,,,,,,,,.(###(#%%%%**////(((/////%&%(///////**(#*/(#(............,@@&&.
//       .,//*((//***#%&&&&%#%%%&&&&&&%&&&&&/#%#&&&&&&#(/#(#%####((***/((/**///*
//         .*/((((((%%%%%%%%%#%%%%%#%%%%&#%*%##%&&&###(%####/%((%##/(((((#((*.
//             ..... **(#######%%####%%%%%%%%%%%%%%(&(%%%%#%(/(/*,   .....,..
//                     ,/(###%%%#%%%%%%&%%(&&&%&*(%(%&&&&%##%(/
//                        ///###%%%%%&&&@&&&&&%/%,&&&&&%%%%/*
//                            /((##%%&&&&@&&&&&&&%&&&%%%#
//                                   (##%%%%%%&&&&

/*
This is the official contract of JackpotUniverse token. This token
is the official successor of LAS (Last Ape Standing) BSC token.
LAS was the first token of its kind to implement an innovative jackpot mechanism.
JUNI builds upon that innovation and brings in a creative referral system and expands
on the jackpot paradigm.

Every buy and sell will feed 1 main and 3 secondary jackpots (bronze, silver and gold).
Secondary jackpots will be cashed out at specific intervals of time as a true lottery-ticket system. The main
jackpot adheres to the same rules as that of LAS. If for 10 mins, no buys are recorded, the last buyer
will receive a portion of the jackpot.

The main jackpot has a hard limit ($100K) that, if reached, will trigger the big bang event. A portion
of the jackpot will be cashed out to the buyback wallet. The buyback wallet will
then either burn the tokens or dedicate a portion of it towards staking.

Website: https://www.juni.gg
Twitter: https://twitter.com/JUNIBSC
Instagram: https://www.instagram.com/juniversebsc/
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 *  Trying to delete such a structure from storage will likely result in data corruption, rendering the structure unusable.
 *  See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 *  In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

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

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value)
        private
        view
        returns (bool)
    {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index)
        private
        view
        returns (bytes32)
    {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value)
        internal
        returns (bool)
    {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value)
        internal
        returns (bool)
    {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value)
        internal
        view
        returns (bool)
    {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index)
        internal
        view
        returns (bytes32)
    {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set)
        internal
        view
        returns (bytes32[] memory)
    {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value)
        internal
        view
        returns (bool)
    {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index)
        internal
        view
        returns (address)
    {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set)
        internal
        view
        returns (address[] memory)
    {
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

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value)
        internal
        returns (bool)
    {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value)
        internal
        view
        returns (bool)
    {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index)
        internal
        view
        returns (uint256)
    {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set)
        internal
        view
        returns (uint256[] memory)
    {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

interface IJackpotGuard {
    function getJackpotQualifier(
        address routerAddress,
        address jpToken,
        uint256 jackpotMinBuy,
        uint256 tokenAmount
    ) external view returns (uint256);

    function usdEquivalent(address router, uint256 bnbAmount)
        external
        view
        returns (uint256);

    function isJackpotEligibleOnAward(address user)
        external
        view
        returns (bool);

    function isJackpotEligibleOnBuy(address user) external view returns (bool);

    function isRestricted(address user) external view returns (bool);

    function ban(address user) external;

    function ban(address[] calldata users) external;

    function unban(address user) external;

    function unban(address[] calldata users) external;
}

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;
    address private _lockedLiquidity;
    address payable private _teamWallet;
    address payable private _marketingWallet;
    address payable private _buybackWallet;

    mapping(address => bool) internal authorizations;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event AuthorizationGranted(address indexed wallet);
    event AuthorizationRevoked(address indexed wallet);

    event TeamWalletChanged(address indexed from, address indexed to);
    event MarketingWalletChanged(address indexed from, address indexed to);
    event BuybackWalletChanged(address indexed from, address indexed to);
    event LockedLiquidityAddressChanged(
        address indexed from,
        address indexed to
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        require(
            initialOwner != address(0),
            "Initial owner can't be the zero address"
        );
        _owner = initialOwner;

        emit OwnershipTransferred(address(0), initialOwner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    function lockedLiquidity() public view returns (address) {
        return _lockedLiquidity;
    }

    function teamWallet() public view returns (address payable) {
        return _teamWallet;
    }

    function marketingWallet() public view returns (address payable) {
        return _marketingWallet;
    }

    function buybackWallet() public view returns (address payable) {
        return _buybackWallet;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Throws if called by any account other than the team wallet owner.
     */
    modifier onlyTeam() {
        require(
            _teamWallet == _msgSender(),
            "Ownable: caller is not the team wallet owner"
        );
        _;
    }

    /**
     * @dev Throws if called by any account other than the marketing wallet owner.
     */
    modifier onlyMarketing() {
        require(
            _marketingWallet == _msgSender(),
            "Ownable: caller is not the marketing wallet owner"
        );
        _;
    }

    /**
     * @dev Throws if called by any account other than the buyback wallet owner.
     */
    modifier onlyBuyback() {
        require(
            _buybackWallet == _msgSender(),
            "Ownable: caller is not the buyback wallet owner"
        );
        _;
    }

    function setTeamWalletAddress(address payable teamWalletAddress)
        public
        virtual
        onlyOwner
    {
        require(
            teamWalletAddress != address(0),
            "You must supply a non-zero address"
        );
        _teamWallet = teamWalletAddress;
        emit TeamWalletChanged(_teamWallet, teamWalletAddress);
    }

    function setMarketingWalletAddress(address payable marketingWalletAddress)
        public
        virtual
        onlyOwner
    {
        require(
            marketingWalletAddress != address(0),
            "You must supply a non-zero address"
        );
        _marketingWallet = marketingWalletAddress;
        emit MarketingWalletChanged(_marketingWallet, marketingWalletAddress);
    }

    function setBuybackWallet(address payable buybackWalletAddress)
        public
        virtual
        onlyOwner
    {
        require(
            buybackWalletAddress != address(0),
            "You must supply a non-zero address"
        );
        _buybackWallet = buybackWalletAddress;
        emit BuybackWalletChanged(_buybackWallet, buybackWalletAddress);
    }

    function setLockedLiquidityAddress(address liquidityAddress)
        public
        virtual
        onlyOwner
    {
        // Zero address is fine, as to lock liquidity
        // Ideally, we'll be locking these tokens manually up to X months
        _lockedLiquidity = liquidityAddress;
        emit LockedLiquidityAddressChanged(_lockedLiquidity, liquidityAddress);
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _owner = address(0);
        emit OwnershipTransferred(_owner, address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _owner = newOwner;

        emit OwnershipTransferred(_owner, newOwner);
    }

    /**
     * Function modifier to require caller to be authorized
     */
    modifier onlyAuthorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED");
        _;
    }

    /**
     * Authorize address. Owner only
     */
    function authorize(address adr) public onlyOwner {
        require(
            !authorizations[adr] && adr != owner(),
            "Address is already authorized"
        );
        authorizations[adr] = true;

        emit AuthorizationGranted(adr);
    }

    /**
     * Remove address' authorization. Owner only
     */
    function unauthorize(address adr) public onlyOwner {
        require(
            authorizations[adr] && adr != owner(),
            "Address is already NOT authorized"
        );
        authorizations[adr] = false;

        emit AuthorizationRevoked(adr);
    }

    /**
     * Return address' authorization status
     */
    function isAuthorized(address adr) public view returns (bool) {
        return adr == owner() || authorizations[adr];
    }
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IJackpotReferral {
    function refer(
        address sender,
        address recipient,
        uint256 amount
    ) external;

    function claimRewardTicket() external;

    function awardTickets(address wallet, uint256 amount) external;
}

enum JackpotState {
    Inactive,
    Active,
    Decision,
    Awarded
}
enum JackpotRank {
    Bronze,
    Silver,
    Gold,
    Misc
}

struct User {
    address wallet;
    uint256 bronzeTickets;
    uint256 bronzeId;
    uint256 silverTickets;
    uint256 silverId;
    uint256 goldTickets;
    uint256 goldId;
    uint256 miscTickets;
    uint256 miscId;
}

struct RankedJackpot {
    uint256 id;
    JackpotRank rank;
    JackpotState state;
    bool isNative;
    address ticketToken;
    address awardToken;
    uint256 value;
    uint256 timespan;
    uint256 createdAt;
    uint256 lastUserAmount;
    address lastUser;
    uint256 totalUsers;
    uint256 totalTickets;
}

interface IJackpotBroker {
    function fundJackpots(
        uint256 bronze,
        uint256 silver,
        uint256 gold
    ) external payable;

    function processBroker() external;
}

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
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

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
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

        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
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

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return
            functionDelegateCall(
                target,
                data,
                "Address: low-level delegate call failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
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

enum TaxId {
    Liquidity,
    Marketing,
    Team,
    Jackpot,
    BronzeJackpot,
    SilverJackpot,
    GoldJackpot
}

struct Tax {
    uint256 buyFee;
    uint256 sellFee;
    uint256 pendingTokens;
    uint256 pendingBalance;
    uint256 claimedBalance;
}

abstract contract Treasury is Ownable {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private constant MAX_PCT = 10000;
    // At any given time, buy and sell fees can NOT exceed 25% each
    uint256 private constant TOTAL_FEES_LIMIT = 2500;

    uint256 private totalSupply;

    uint256 public maxWalletSize;

    // The minimum transaction limit that can be set is 0.1% of the total supply
    uint256 internal constant MIN_TX_LIMIT = 10;
    uint256 public maxTxAmount;

    uint256 public numTokensSellToAddToLiquidity;

    EnumerableSet.AddressSet private _txLimitExempt;
    EnumerableSet.AddressSet private _maxWalletExempt;
    EnumerableSet.AddressSet private _feeExempt;
    EnumerableSet.AddressSet private _swapExempt;

    mapping(TaxId => Tax) private taxes;

    event BuyFeesChanged(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 teamFee
    );

    event JackpotBuyFeesChanged(
        uint256 jackpotFee,
        uint256 bronzeJackpotFee,
        uint256 silverJackpotFee,
        uint256 goldJackpotFee
    );

    event SellFeesChanged(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 teamFee
    );

    event JackpotSellFeesChanges(
        uint256 jackpotFee,
        uint256 bronzeJackpotFee,
        uint256 silverJackpotFee,
        uint256 goldJackpotFee
    );

    event MaxTransferAmountChanged(uint256 maxTxAmount);

    event MaxWalletSizeChanged(uint256 maxWalletSize);

    event TokenToSellOnSwapChanged(uint256 numTokens);

    event FeesCollected(uint256 bnbCollected);

    constructor(uint256 total, uint256 decimals) {
        totalSupply = total;
        // Max wallet size initially set to 1%
        maxWalletSize = total / 100;
        // Initially, max TX amount is set to the total supply
        maxTxAmount = total;

        numTokensSellToAddToLiquidity = 2000 * 10**decimals;

        Tax storage liqTax = taxes[TaxId.Liquidity];
        // Initial liquidity taxes = Buy (0%) Sell (0%)
        liqTax.buyFee = 0;
        liqTax.sellFee = 0;

        Tax storage marketingTax = taxes[TaxId.Marketing];
        // Initial marketing taxes = Buy (2%) Sell (2%)
        marketingTax.buyFee = 200;
        marketingTax.sellFee = 200;

        Tax storage teamTax = taxes[TaxId.Team];
        // Initial team taxes = Buy (2%) Sell (2%)
        // Who wants to work for free?
        teamTax.buyFee = 200;
        teamTax.sellFee = 200;

        Tax storage jackpotTax = taxes[TaxId.Jackpot];
        // Initial MAIN jackpot taxes = Buy (4%) Sell (4%)
        jackpotTax.buyFee = 400;
        jackpotTax.sellFee = 400;

        Tax storage bronzeJackpotTax = taxes[TaxId.BronzeJackpot];
        // Initial bronze jackpot taxes = Buy (2%) Sell (2%)
        bronzeJackpotTax.buyFee = 200;
        bronzeJackpotTax.sellFee = 200;

        Tax storage silverJackpotTax = taxes[TaxId.SilverJackpot];
        // Initial silver jackpot taxes = Buy (1%) Sell (1%)
        silverJackpotTax.buyFee = 100;
        silverJackpotTax.sellFee = 100;

        Tax storage goldJackpotTax = taxes[TaxId.GoldJackpot];
        // Initial gold jackpot taxes = Buy (1%) Sell (1%)
        goldJackpotTax.buyFee = 100;
        goldJackpotTax.sellFee = 100;
    }

    function isTxLimitExempt(address account) public view returns (bool) {
        return _txLimitExempt.contains(account);
    }

    function exemptFromTxLimit(address account) public onlyAuthorized {
        _txLimitExempt.add(account);
    }

    function includeInTxLimit(address account) public onlyAuthorized {
        _txLimitExempt.remove(account);
    }

    function isMaxWalletExempt(address account) public view returns (bool) {
        return _maxWalletExempt.contains(account);
    }

    function exemptFromMaxWallet(address account) public onlyAuthorized {
        _maxWalletExempt.add(account);
    }

    function includeInMaxWallet(address account) public onlyAuthorized {
        _maxWalletExempt.remove(account);
    }

    function isFeeExempt(address account) public view returns (bool) {
        return _feeExempt.contains(account);
    }

    function exemptFromFee(address account) public onlyAuthorized {
        _feeExempt.add(account);
    }

    function includeInFee(address account) public onlyAuthorized {
        _feeExempt.remove(account);
    }

    function isSwapAndLiquifyExempt(address account)
        public
        view
        returns (bool)
    {
        return _swapExempt.contains(account);
    }

    function exemptFromSwapAndLiquify(address account) public onlyOwner {
        _swapExempt.add(account);
    }

    function includeInSwapAndLiquify(address account) public onlyOwner {
        _swapExempt.remove(account);
    }

    function exemptFromAll(address account) public onlyOwner {
        exemptFromFee(account);
        exemptFromMaxWallet(account);
        exemptFromTxLimit(account);
    }

    function setBuyFees(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 teamFee
    ) external onlyAuthorized {
        require(
            (liquidityFee +
                marketingFee +
                teamFee +
                taxes[TaxId.Jackpot].buyFee +
                taxes[TaxId.BronzeJackpot].buyFee +
                taxes[TaxId.SilverJackpot].buyFee +
                taxes[TaxId.GoldJackpot].buyFee) <= TOTAL_FEES_LIMIT,
            "Total buy fees can not exceed the declared limit"
        );
        taxes[TaxId.Liquidity].buyFee = liquidityFee;
        taxes[TaxId.Marketing].buyFee = marketingFee;
        taxes[TaxId.Team].buyFee = teamFee;

        emit BuyFeesChanged(liquidityFee, marketingFee, teamFee);
    }

    function setJackpotBuyFees(
        uint256 jackpotFee,
        uint256 bronzeJackpotFee,
        uint256 silverJackpotFee,
        uint256 goldJackpotFee
    ) external onlyAuthorized {
        require(
            (taxes[TaxId.Liquidity].buyFee +
                taxes[TaxId.Marketing].buyFee +
                taxes[TaxId.Team].buyFee +
                jackpotFee +
                bronzeJackpotFee +
                silverJackpotFee +
                goldJackpotFee) <= TOTAL_FEES_LIMIT,
            "Total jackpot buy fees can not exceed the declared limit"
        );
        taxes[TaxId.Jackpot].buyFee = jackpotFee;
        taxes[TaxId.BronzeJackpot].buyFee = bronzeJackpotFee;
        taxes[TaxId.SilverJackpot].buyFee = silverJackpotFee;
        taxes[TaxId.GoldJackpot].buyFee = goldJackpotFee;

        emit JackpotBuyFeesChanged(
            jackpotFee,
            bronzeJackpotFee,
            silverJackpotFee,
            goldJackpotFee
        );
    }

    function getBuyTax() public view returns (uint256) {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256 buyTax = 0;

        for (uint8 i = min; i <= max; i++) {
            buyTax += taxes[TaxId(i)].buyFee;
        }

        return buyTax;
    }

    function getBuyFee(TaxId id) public view returns (uint256) {
        return taxes[id].buyFee;
    }

    function setSellFees(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 teamFee
    ) external onlyAuthorized {
        require(
            (liquidityFee +
                marketingFee +
                teamFee +
                taxes[TaxId.Jackpot].sellFee +
                taxes[TaxId.BronzeJackpot].sellFee +
                taxes[TaxId.SilverJackpot].sellFee +
                taxes[TaxId.GoldJackpot].sellFee) <= TOTAL_FEES_LIMIT,
            "Total sell fees can not exceed the declared limit"
        );

        taxes[TaxId.Liquidity].sellFee = liquidityFee;
        taxes[TaxId.Marketing].sellFee = marketingFee;
        taxes[TaxId.Team].sellFee = teamFee;

        emit SellFeesChanged(liquidityFee, marketingFee, teamFee);
    }

    function setJackpotSellFees(
        uint256 jackpotFee,
        uint256 bronzeJackpotFee,
        uint256 silverJackpotFee,
        uint256 goldJackpotFee
    ) external onlyAuthorized {
        require(
            (taxes[TaxId.Liquidity].sellFee +
                taxes[TaxId.Marketing].sellFee +
                taxes[TaxId.Team].sellFee +
                jackpotFee +
                bronzeJackpotFee +
                silverJackpotFee +
                goldJackpotFee) <= TOTAL_FEES_LIMIT,
            "Total jackpot sell fees can not exceed the declared limit"
        );
        taxes[TaxId.Jackpot].sellFee = jackpotFee;
        taxes[TaxId.BronzeJackpot].sellFee = bronzeJackpotFee;
        taxes[TaxId.SilverJackpot].sellFee = silverJackpotFee;
        taxes[TaxId.GoldJackpot].sellFee = goldJackpotFee;

        emit JackpotBuyFeesChanged(
            jackpotFee,
            bronzeJackpotFee,
            silverJackpotFee,
            goldJackpotFee
        );
    }

    function getSellTax() public view returns (uint256) {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256 sellTax = 0;

        // Enums hold a max of 256 entries, so uint8 will suffice
        for (uint8 i = min; i <= max; i++) {
            sellTax += taxes[TaxId(i)].sellFee;
        }

        return sellTax;
    }

    function getSellFee(TaxId id) public view returns (uint256) {
        return taxes[id].sellFee;
    }

    function setMaxTxAmount(uint256 txAmount) external onlyAuthorized {
        require(
            txAmount >= (totalSupply * MIN_TX_LIMIT) / MAX_PCT,
            "Maximum transaction limit can't be less than 0.1% of the total supply"
        );
        maxTxAmount = txAmount;

        emit MaxTransferAmountChanged(maxTxAmount);
    }

    function setMaxWallet(uint256 amount) external onlyAuthorized {
        require(
            amount >= totalSupply / 1000,
            "Max wallet size must be at least 0.1% of the total supply"
        );
        maxWalletSize = amount;

        emit MaxWalletSizeChanged(maxWalletSize);
    }

    function setNumTokensSellToAddToLiquidity(uint256 numTokens)
        external
        onlyAuthorized
    {
        numTokensSellToAddToLiquidity = numTokens;

        emit TokenToSellOnSwapChanged(numTokensSellToAddToLiquidity);
    }

    function getPendingAssets(TaxId id) public view returns (uint256, uint256) {
        return (taxes[id].pendingBalance, taxes[id].pendingTokens);
    }

    function getClaimedBalance(TaxId id) public view returns (uint256) {
        return taxes[id].claimedBalance;
    }

    function collectFees(TaxId id, address payable wallet) internal {
        uint256 toTransfer = getPendingBalance(id);
        decPendingBalance(id, toTransfer, true);
        Address.sendValue(wallet, toTransfer);
        emit FeesCollected(toTransfer);
    }

    function collectMarketingFees() external onlyMarketing {
        collectFees(TaxId.Marketing, marketingWallet());
    }

    function collectTeamFees() external onlyTeam {
        collectFees(TaxId.Team, teamWallet());
    }

    function getPendingTokens() public view returns (uint256[] memory) {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256[] memory tokens = new uint256[](max - min + 1);

        for (uint8 i = min; i <= max; i++) {
            tokens[i] = taxes[TaxId(i)].pendingTokens;
        }

        return tokens;
    }

    function getPendingTokensTotal() public view returns (uint256) {
        uint256[] memory tokens = getPendingTokens();
        uint256 pendingTokensTotal = 0;

        for (uint8 i = 0; i < tokens.length; i++) {
            pendingTokensTotal += tokens[i];
        }

        return pendingTokensTotal;
    }

    function getPendingBalances() public view returns (uint256[] memory) {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);

        uint256[] memory balances = new uint256[](max - min + 1);

        for (uint8 i = min; i <= max; i++) {
            balances[i] = taxes[TaxId(i)].pendingBalance;
        }

        return balances;
    }

    function getPendingBalancesTotal() external view returns (uint256) {
        uint256[] memory balances = getPendingBalances();
        uint256 pendingBalancesTotal = 0;
        for (uint8 i = 0; i < balances.length; i++) {
            pendingBalancesTotal += balances[i];
        }

        return pendingBalancesTotal;
    }

    function getPendingBalance(TaxId id) internal view returns (uint256) {
        return taxes[id].pendingBalance;
    }

    function incPendingBalance(TaxId id, uint256 amount) internal {
        taxes[id].pendingBalance += amount;
    }

    function decPendingBalance(
        TaxId id,
        uint256 amount,
        bool claim
    ) internal {
        taxes[id].pendingBalance -= amount;
        if (claim) {
            taxes[id].claimedBalance += amount;
        }
    }

    function resetPendingBalances() internal {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);

        for (uint8 i = min; i <= max; i++) {
            decPendingBalance(TaxId(i), taxes[TaxId(i)].pendingBalance, false);
        }
    }

    function getPendingTokens(TaxId id) internal view returns (uint256) {
        return taxes[id].pendingTokens;
    }

    function setPendingTokens(TaxId id, uint256 amount) internal {
        taxes[id].pendingTokens = amount;
    }

    function incPendingTokens(TaxId id, uint256 amount) internal {
        taxes[id].pendingTokens += amount;
    }

    function decPendingTokens(TaxId id, uint256 amount) internal {
        taxes[id].pendingTokens -= amount;
    }

    function resetPendingTokens() internal {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);

        for (uint8 i = min; i <= max; i++) {
            taxes[TaxId(i)].pendingTokens = 0;
        }
    }
}

abstract contract JackpotToken is Ownable, Treasury {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    // 100%
    uint256 internal constant MAX_PCT = 10000;
    uint256 internal constant BNB_DECIMALS = 18;
    uint256 internal constant USDT_DECIMALS = 18;
    address internal constant DEFAULT_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // PCS takes 0.25% fee on all txs
    uint256 private constant ROUTER_FEE = 25;

    uint256 private constant JACKPOT_TIMESPAN_LIMIT_MIN = 20;

    // Jackpot related variables
    // 55.55% jackpot cashout to last buyer
    uint256 public jackpotCashout = 5555;
    // 90% of jackpot cashout to last buyer
    uint256 public jackpotBuyerShare = 9000;
    // Buys > 0.1 BNB will be eligible for the jackpot
    uint256 public jackpotMinBuy = 1 * 10**(BNB_DECIMALS - 1);
    // Jackpot time span is initially set to 10 mins
    uint256 public jackpotTimespan = 10 * 60;
    // Jackpot hard limit, USD value, $100K
    uint256 public jackpotHardLimit = 100000 * 10**(USDT_DECIMALS);
    // Jackpot hard limit buyback share
    uint256 public jackpotHardBuyback = 5000;

    address payable internal _lastBuyer = payable(address(this));
    uint256 internal _lastBuyTimestamp = 0;

    address internal _lastAwarded = address(0);
    uint256 internal _lastAwardedCash = 0;
    uint256 internal _lastAwardedTokens = 0;
    uint256 internal _lastAwardedTimestamp = 0;

    uint256 internal _lastBigBangCash = 0;
    uint256 internal _lastBigBangTokens = 0;
    uint256 internal _lastBigBangTimestamp = 0;

    // Total BNB/JUNI collected by the jackpot
    uint256 internal _totalJackpotCashedOut = 0;
    uint256 internal _totalJackpotTokensOut = 0;
    uint256 internal _totalJackpotBuyer = 0;
    uint256 internal _totalJackpotBuyback = 0;
    uint256 internal _totalJackpotBuyerTokens = 0;
    uint256 internal _totalJackpotBuybackTokens = 0;

    bool public jackpotEnabled = true;

    // This will represent the default swap router
    IUniswapV2Router02 internal swapRouter;
    EnumerableSet.AddressSet internal liquidityPools;
    mapping(address => address) internal swapRouters;

    event JackpotAwarded(
        address winner,
        uint256 cashedOut,
        uint256 tokensOut,
        uint256 buyerShare,
        uint256 tokensToBuyer,
        uint256 toBuyback,
        uint256 tokensToBuyback
    );
    event BigBang(uint256 cashedOut, uint256 tokensOut);

    event JackpotMinBuyChanged(uint256 jackpotMinBuy);

    event JackpotFeaturesChanged(
        uint256 jackpotCashout,
        uint256 jackpotBuyerShare
    );

    event JackpotTimespanChanged(uint256 jackpotTimespan);

    event BigBangFeaturesChanged(
        uint256 jackpotHardBuyback,
        uint256 jackpotHardLimit
    );

    event JackpotFund(uint256 bnbSent, uint256 tokenAmount);

    event JackpotStatusChanged(bool status);

    event LiquidityRouterChanged(address router);

    event LiquidityPoolAdded(address pool);

    event LiquidityPoolRemoved(address pool);

    constructor() Ownable(msg.sender) {
        swapRouter = IUniswapV2Router02(DEFAULT_ROUTER);
        address pool = IUniswapV2Factory(swapRouter.factory()).createPair(
            address(this),
            swapRouter.WETH()
        );
        liquidityPools.add(pool);
        exemptFromSwapAndLiquify(pool);
        swapRouters[pool] = DEFAULT_ROUTER;
    }

    function setSwapRouter(address otherRouterAddress) external onlyOwner {
        swapRouter = IUniswapV2Router02(otherRouterAddress);

        emit LiquidityRouterChanged(otherRouterAddress);
    }

    function addLiquidityPool(address poolAddress, address router)
        external
        onlyOwner
    {
        require(
            poolAddress != address(0) && router != address(0),
            "Pool and router both can't be the zero address"
        );
        liquidityPools.add(poolAddress);
        // Must exempt swap pair to avoid double dipping on swaps
        exemptFromSwapAndLiquify(poolAddress);
        swapRouters[poolAddress] = router;

        emit LiquidityPoolAdded(poolAddress);
    }

    function delLiquidityPool(address poolAddress) external onlyOwner {
        liquidityPools.remove(poolAddress);
        includeInSwapAndLiquify(poolAddress);
        swapRouters[poolAddress] = address(0);

        emit LiquidityPoolRemoved(poolAddress);
    }

    function awardJackpot() internal virtual;

    function processBigBang() internal virtual;

    function resetJackpot() internal {
        _lastBuyTimestamp = 0;
        _lastBuyer = payable(address(this));
    }

    function setJackpotStatus(bool status) external onlyAuthorized {
        jackpotEnabled = status;
        resetJackpot();
        emit JackpotStatusChanged(status);
    }

    function totalJackpotStats()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _totalJackpotCashedOut,
            _totalJackpotTokensOut,
            _totalJackpotBuyer,
            _totalJackpotBuyerTokens,
            _totalJackpotBuyback,
            _totalJackpotBuybackTokens
        );
    }

    function setJackpotMinBuy(uint256 _jackpotMinBuy) external onlyAuthorized {
        jackpotMinBuy = _jackpotMinBuy;

        resetJackpot();

        emit JackpotMinBuyChanged(jackpotMinBuy);
    }

    function setJackpotFeatures(
        uint256 _jackpotCashout,
        uint256 _jackpotBuyerShare
    ) external onlyAuthorized {
        require(
            _jackpotCashout <= MAX_PCT,
            "Percentage amount needs to be less than or equal 100%"
        );
        require(
            _jackpotBuyerShare <= MAX_PCT,
            "Percentage amount needs to be less than or equal 100%"
        );
        jackpotCashout = _jackpotCashout;
        jackpotBuyerShare = _jackpotBuyerShare;

        emit JackpotFeaturesChanged(jackpotCashout, jackpotBuyerShare);
    }

    function setJackpotHardFeatures(
        uint256 _jackpotHardBuyback,
        uint256 _jackpotHardLimit
    ) external onlyAuthorized {
        require(
            _jackpotHardBuyback <= MAX_PCT,
            "Jackpot hard buyback percentage needs to be between 30% and 70%"
        );
        jackpotHardBuyback = _jackpotHardBuyback;
        jackpotHardLimit = _jackpotHardLimit;

        emit BigBangFeaturesChanged(jackpotHardBuyback, jackpotHardLimit);
    }

    function setJackpotTimespanInSeconds(uint256 _jackpotTimespan)
        external
        onlyAuthorized
    {
        require(
            _jackpotTimespan >= JACKPOT_TIMESPAN_LIMIT_MIN,
            "Jackpot timespan needs to be greater than 20 seconds"
        );
        jackpotTimespan = _jackpotTimespan;
        resetJackpot();

        emit JackpotTimespanChanged(jackpotTimespan);
    }

    function getLastBuy() public view returns (address, uint256) {
        return (_lastBuyer, _lastBuyTimestamp);
    }

    function getLastAwarded()
        public
        view
        returns (
            address,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _lastAwarded,
            _lastAwardedCash,
            _lastAwardedTokens,
            _lastAwardedTimestamp
        );
    }

    function getLastBigBang()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (_lastBigBangCash, _lastBigBangTokens, _lastBigBangTimestamp);
    }
}

contract JackpotUniverse is IERC20, JackpotToken {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private constant NAME = "JackpotUniverse";
    string private constant SYMBOL = "JUNI";
    uint8 private constant DECIMALS = 9;
    uint256 private constant TOTAL = 10000000 * 10**DECIMALS;

    // We don't add to liquidity unless we have at least 1 JUNI token
    uint256 private constant LIQ_SWAP_THRESH = 10**DECIMALS;

    // Liquidity
    bool public swapAndLiquifyEnabled = true;
    bool private _inSwapAndLiquify;

    bool public tradingOpen = false;
    bool public jackpotLimited = true;

    IJackpotBroker private jBroker;
    IJackpotGuard private jGuard;
    IJackpotReferral private jReferral;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiquidity
    );

    event ValueReceived(address origin, address user, uint256 amount);

    event ValueReceivedInFallback(address origin, address user, uint256 amount);

    event JackpotGuardChanged(address oldGuard, address newGuard);

    event JackpotReferralChanged(address oldBroker, address newBroker);

    event JackpotBrokerChanged(address oldBroker, address newBroker);

    event JackpotLimited(bool limited);

    event TradingStatusChanged(bool status);

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    constructor(
        address jGuardAddr,
        address jReferralAddr,
        address jBrokerAddr
    ) Treasury(TOTAL, DECIMALS) {
        jGuard = IJackpotGuard(jGuardAddr);
        emit JackpotGuardChanged(address(0), jGuardAddr);

        jReferral = IJackpotReferral(jReferralAddr);
        emit JackpotReferralChanged(address(0), jReferralAddr);

        jBroker = IJackpotBroker(jBrokerAddr);
        emit JackpotBrokerChanged(address(0), jBrokerAddr);

        _balances[msg.sender] = TOTAL;

        // Exempts from fees, tx limit and max wallet
        exemptFromAll(owner());
        exemptFromAll(address(this));

        emit Transfer(address(0), msg.sender, TOTAL);
    }

    receive() external payable {
        if (msg.value > 0) {
            emit ValueReceived(tx.origin, msg.sender, msg.value);
        }
    }

    fallback() external payable {
        if (msg.value > 0) {
            emit ValueReceivedInFallback(tx.origin, msg.sender, msg.value);
        }
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() public pure returns (uint256) {
        return TOTAL;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address wallet, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[wallet][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        approve(_msgSender(), spender, amount);
        return true;
    }

    function approve(
        address wallet,
        address spender,
        uint256 amount
    ) private {
        require(wallet != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[wallet][spender] = amount;
        emit Approval(wallet, spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            _allowances[sender][_msgSender()] >= amount,
            "BEP20: transfer amount exceeds allowance"
        );
        transfer(sender, recipient, amount);
        approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        require(
            _allowances[_msgSender()][spender] >= subtractedValue,
            "BEP20: decreased allowance below zero"
        );
        approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function fundJackpot(uint256 tokenAmount) external payable onlyAuthorized {
        require(
            balanceOf(msg.sender) >= tokenAmount,
            "You don't have enough tokens to fund the jackpot"
        );
        uint256 bnbSent = msg.value;
        incPendingBalance(TaxId.Jackpot, bnbSent);
        if (tokenAmount > 0) {
            transferBasic(msg.sender, address(this), tokenAmount);
            incPendingTokens(TaxId.Jackpot, tokenAmount);
        }

        emit JackpotFund(bnbSent, tokenAmount);
    }

    function getUsedTokens(
        uint256 accSum,
        uint256 tokenAmount,
        uint256 tokens
    ) private pure returns (uint256, uint256) {
        if (accSum >= tokenAmount) {
            return (0, accSum);
        }
        uint256 available = tokenAmount - accSum;
        if (tokens <= available) {
            return (tokens, accSum + tokens);
        }
        return (available, accSum + available);
    }

    function getTokenShares(uint256 tokenAmount)
        private
        returns (uint256[] memory, uint256)
    {
        uint256 accSum = 0;
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256[] memory tokens = new uint256[](max - min + 1);

        for (uint8 i = min; i <= max; i++) {
            TaxId id = TaxId(i);
            uint256 pendingTokens = getPendingTokens(id);
            (tokens[i], accSum) = getUsedTokens(
                accSum,
                tokenAmount,
                pendingTokens
            );
            decPendingTokens(id, tokens[i]);
        }

        return (tokens, accSum);
    }

    function setSwapAndLiquifyEnabled(bool enabled) public onlyOwner {
        swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(enabled);
    }

    function setJackpotBroker(address otherBroker) external onlyOwner {
        address oldBroker = address(jBroker);
        jBroker = IJackpotBroker(otherBroker);

        emit JackpotBrokerChanged(oldBroker, otherBroker);
    }

    function setJackpotReferral(address otherReferral) external onlyOwner {
        address oldReferral = address(jReferral);
        jReferral = IJackpotReferral(otherReferral);

        emit JackpotReferralChanged(oldReferral, otherReferral);
    }

    function setJackpotGuard(address otherGuard) external onlyOwner {
        address oldGuard = address(jGuard);
        jGuard = IJackpotGuard(otherGuard);

        emit JackpotGuardChanged(oldGuard, otherGuard);
    }

    function setJackpotLimited(bool limited) external onlyOwner {
        jackpotLimited = limited;

        emit JackpotLimited(limited);
    }

    function transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!jGuard.isRestricted(from), "Source wallet is banned");
        require(!jGuard.isRestricted(to), "Destination wallet is banned");

        if (from != owner() && to != owner()) {
            require(
                isTxLimitExempt(from) ||
                    isTxLimitExempt(to) ||
                    amount <= maxTxAmount,
                "Transfer amount exceeds the maxTxAmount"
            );
        }

        if (!isAuthorized(from) && !isAuthorized(to)) {
            require(tradingOpen, "Trading is currently not open");
        }

        // Jackpot mechanism locks the swap if triggered. We should handle it as
        // soon as possible so that we could award the jackpot on a sell and on a buy
        if (
            !_inSwapAndLiquify &&
            jackpotEnabled &&
            jGuard.usdEquivalent(
                address(swapRouter),
                getPendingBalance(TaxId.Jackpot)
            ) >=
            jackpotHardLimit
        ) {
            processBigBang();
            resetJackpot();
        } else if (
            // We can't award the jackpot in swap and liquify
            // Pending balances need to be untouched (externally) for swaps
            !_inSwapAndLiquify &&
            jackpotEnabled &&
            _lastBuyer != address(0) &&
            _lastBuyer != address(this) &&
            (block.timestamp - _lastBuyTimestamp) >= jackpotTimespan
        ) {
            awardJackpot();
        }

        uint256 pendingTokens = getPendingTokensTotal();

        if (pendingTokens >= maxTxAmount) {
            pendingTokens = maxTxAmount;
        }

        if (
            pendingTokens >= numTokensSellToAddToLiquidity &&
            !_inSwapAndLiquify &&
            !isSwapAndLiquifyExempt(from) &&
            swapAndLiquifyEnabled
        ) {
            swapAndLiquify(numTokensSellToAddToLiquidity);
            fundJackpots();
        }
        // Check if any secondary jackpots are ready to be awarded
        jBroker.processBroker();

        tokenTransfer(from, to, amount);
    }

    function withdrawBnb() external onlyOwner {
        uint256 excess = address(this).balance;
        require(excess > 0, "No BNBs to withdraw");
        resetPendingBalances();
        Address.sendValue(payable(_msgSender()), excess);
    }

    function withdrawNativeTokens() external onlyOwner {
        uint256 excess = balanceOf(address(this));
        require(excess > 0, "No tokens to withdraw");
        resetPendingTokens();
        transferBasic(address(this), _msgSender(), excess);
    }

    function withdrawOtherTokens(address token) external onlyOwner {
        require(
            token != address(this),
            "Use the appropriate native token withdraw method"
        );
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        IERC20(token).transfer(_msgSender(), balance);
    }

    function setTradingStatus(bool status) external onlyOwner {
        tradingOpen = status;
        emit TradingStatusChanged(status);
    }

    function jackpotBuyerShareAmount()
        external
        view
        returns (uint256, uint256)
    {
        TaxId id = TaxId.Jackpot;
        uint256 bnb = (getPendingBalance(id) *
            jackpotCashout *
            jackpotBuyerShare) / MAX_PCT**2;
        uint256 tokens = (getPendingTokens(id) *
            jackpotCashout *
            jackpotBuyerShare) / MAX_PCT**2;
        return (bnb, tokens);
    }

    function jackpotBuybackAmount() external view returns (uint256, uint256) {
        TaxId id = TaxId.Jackpot;
        uint256 bnb = (getPendingBalance(id) *
            jackpotCashout *
            (MAX_PCT - jackpotBuyerShare)) / MAX_PCT**2;
        uint256 tokens = (getPendingTokens(id) *
            jackpotCashout *
            (MAX_PCT - jackpotBuyerShare)) / MAX_PCT**2;

        return (bnb, tokens);
    }

    function processBigBang() internal override lockTheSwap {
        TaxId id = TaxId.Jackpot;
        uint256 cashedOut = (getPendingBalance(id) * jackpotHardBuyback) /
            MAX_PCT;
        uint256 tokensOut = (getPendingTokens(id) * jackpotHardBuyback) /
            MAX_PCT;

        _lastBigBangCash = cashedOut;
        _lastBigBangTokens = tokensOut;
        _lastBigBangTimestamp = block.timestamp;

        decPendingBalance(id, cashedOut, true);
        decPendingTokens(id, tokensOut);

        _totalJackpotCashedOut += cashedOut;
        _totalJackpotBuyback += cashedOut;
        _totalJackpotTokensOut += tokensOut;
        _totalJackpotBuybackTokens += tokensOut;

        transferBasic(address(this), buybackWallet(), tokensOut);
        Address.sendValue(buybackWallet(), cashedOut);

        emit BigBang(cashedOut, tokensOut);
    }

    function awardJackpot() internal override lockTheSwap {
        require(
            _lastBuyer != address(0) && _lastBuyer != address(this),
            "No last buyer detected"
        );

        // Just in case something thought they're smart to circumvent the contract code length check,
        // This will prevent them from winning the jackpot since the contract has been already deployed.
        // So, the next check for jackpot eligibility must fail if the address was truly a contract
        if (!jGuard.isJackpotEligibleOnAward(_lastBuyer)) {
            // Nice try, you win absolutely nothing. Let's reset the jackpot.
            resetJackpot();
            return;
        }

        TaxId id = TaxId.Jackpot;
        uint256 cashedOut = (getPendingBalance(id) * jackpotCashout) / MAX_PCT;
        uint256 tokensOut = (getPendingTokens(id) * jackpotCashout) / MAX_PCT;
        uint256 buyerShare = (cashedOut * jackpotBuyerShare) / MAX_PCT;
        uint256 tokensToBuyer = (tokensOut * jackpotBuyerShare) / MAX_PCT;
        uint256 toBuyback = cashedOut - buyerShare;
        uint256 tokensToBuyback = tokensOut - tokensToBuyer;

        decPendingBalance(id, cashedOut, true);
        decPendingTokens(id, tokensOut);

        _lastAwarded = _lastBuyer;
        _lastAwardedTimestamp = block.timestamp;
        _lastAwardedCash = buyerShare;
        _lastAwardedTokens = tokensToBuyer;

        _lastBuyer = payable(address(this));
        _lastBuyTimestamp = 0;

        _totalJackpotCashedOut += cashedOut;
        _totalJackpotTokensOut += tokensOut;
        _totalJackpotBuyer += buyerShare;
        _totalJackpotBuyerTokens += tokensToBuyer;
        _totalJackpotBuyback += toBuyback;
        _totalJackpotBuybackTokens += tokensToBuyback;

        transferBasic(address(this), _lastAwarded, tokensToBuyer);
        transferBasic(address(this), buybackWallet(), tokensToBuyback);
        // This will never fail since the jackpot is only awarded to wallets
        Address.sendValue(payable(_lastAwarded), buyerShare);
        Address.sendValue(buybackWallet(), toBuyback);

        emit JackpotAwarded(
            _lastAwarded,
            cashedOut,
            tokensOut,
            buyerShare,
            tokensToBuyer,
            toBuyback,
            tokensToBuyback
        );
    }

    function resetJackpotExt() external onlyAuthorized {
        resetJackpot();
    }

    function fundJackpots() internal {
        uint256 bronzeBalance = getPendingBalance(TaxId.BronzeJackpot);
        uint256 silverBalance = getPendingBalance(TaxId.SilverJackpot);
        uint256 goldBalance = getPendingBalance(TaxId.GoldJackpot);
        uint256 totalJpBalance = bronzeBalance + silverBalance + goldBalance;
        if (totalJpBalance > 0) {
            jBroker.fundJackpots{value: totalJpBalance}(
                bronzeBalance,
                silverBalance,
                goldBalance
            );
            decPendingBalance(TaxId.BronzeJackpot, bronzeBalance, true);
            decPendingBalance(TaxId.SilverJackpot, silverBalance, true);
            decPendingBalance(TaxId.GoldJackpot, goldBalance, true);
        }
    }

    function swapAndLiquify(uint256 tokenAmount) private lockTheSwap {
        (uint256[] memory tokens, uint256 toBeSwapped) = getTokenShares(
            tokenAmount
        );
        uint256 liqTokens = tokens[uint8(TaxId.Liquidity)];
        if (liqTokens < LIQ_SWAP_THRESH) {
            // We're not gonna add to liquidity
            incPendingTokens(TaxId.Liquidity, liqTokens);
            liqTokens = 0;
        }

        // This variable holds the liquidity tokens that won't be converted
        uint256 pureLiqTokens = liqTokens / 2;

        // Everything else from the tokens should be converted
        uint256 tokensForBnbExchange = toBeSwapped - pureLiqTokens;

        uint256 initialBalance = address(this).balance;
        swapTokensForBnb(tokensForBnbExchange);

        // How many BNBs did we gain after this conversion?
        uint256 gainedBnb = address(this).balance - initialBalance;

        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256 grantedBalances = 0;
        // Skip liquidity here when processing pending balances
        for (uint8 i = min + 1; i <= max; i++) {
            TaxId id = TaxId(i);
            uint256 balanceToAdd = (gainedBnb * tokens[i]) /
                tokensForBnbExchange;
            incPendingBalance(id, balanceToAdd);
            grantedBalances += balanceToAdd;
        }

        uint256 remainingBnb = gainedBnb - grantedBalances;

        if (liqTokens >= LIQ_SWAP_THRESH) {
            // The leftover BNBs are purely for liquidity here
            // We are not guaranteed to have all the pure liq tokens to be transferred to the pair
            // This is because the uniswap router, PCS in this case, will make a quote based
            // on the current reserves of the pair, so one of the parameters will be fully
            // consumed, but the other will have leftovers.
            uint256 prevBalance = balanceOf(address(this));
            uint256 prevBnbBalance = address(this).balance;
            addLiquidity(pureLiqTokens, remainingBnb);
            uint256 usedBnbs = prevBnbBalance - address(this).balance;
            uint256 usedTokens = prevBalance - balanceOf(address(this));
            // Reallocate the tokens that weren't used back to the internal liquidity tokens tracker
            if (usedTokens < pureLiqTokens) {
                incPendingTokens(TaxId.Liquidity, pureLiqTokens - usedTokens);
            }
            // Reallocate the unused BNBs to the pending marketing wallet balance
            if (usedBnbs < remainingBnb) {
                incPendingBalance(TaxId.Marketing, remainingBnb - usedBnbs);
            }

            emit SwapAndLiquify(tokensForBnbExchange, usedBnbs, usedTokens);
        } else {
            // We could have some dust, so we'll just add it to the pending marketing wallet balance
            incPendingBalance(TaxId.Marketing, remainingBnb);

            emit SwapAndLiquify(tokensForBnbExchange, 0, 0);
        }
    }

    function swapTokensForBnb(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = swapRouter.WETH();

        approve(address(this), address(swapRouter), tokenAmount);
        swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // Approve token transfer to cover all possible scenarios
        approve(address(this), address(swapRouter), tokenAmount);

        // Add the liquidity
        swapRouter.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            lockedLiquidity(),
            block.timestamp
        );
    }

    function tokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        bool takeFee = false;
        bool isBuy = false;
        bool isSenderPool = liquidityPools.contains(sender);
        bool isRecipientPool = liquidityPools.contains(recipient);

        if (isFeeExempt(sender) || isFeeExempt(recipient)) {
            // takeFee is false, so we good
        } else if (isRecipientPool && !isSenderPool) {
            // This is a sell
            takeFee = true;
        } else if (isSenderPool && !isRecipientPool) {
            // If we're here, it must mean that the sender is the uniswap pair
            // This is a buy
            takeFee = true;
            isBuy = true;
            uint256 qualifier = jGuard.getJackpotQualifier(
                swapRouters[sender],
                address(this),
                jackpotMinBuy,
                amount
            );
            if (qualifier >= 1 && jGuard.isJackpotEligibleOnBuy(recipient)) {
                jReferral.awardTickets(recipient, qualifier);
                if (
                    jackpotEnabled &&
                    (!jackpotLimited ||
                        jGuard.usdEquivalent(
                            address(swapRouter),
                            getPendingBalance(TaxId.Jackpot)
                        ) >=
                        jackpotHardLimit / 2)
                ) {
                    _lastBuyTimestamp = block.timestamp;
                    _lastBuyer = payable(recipient);
                }
            }
        } else {
            // Wallet to wallet
            jReferral.refer(sender, recipient, amount);
        }

        transferStandard(sender, recipient, amount, takeFee, isBuy);
    }

    function transferBasic(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        _balances[sender] -= amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function transferStandard(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isBuy
    ) private {
        (uint256 tTransferAmount, uint256 tFees) = processAmount(
            tAmount,
            takeFee,
            isBuy
        );
        if (!liquidityPools.contains(recipient) && recipient != DEAD) {
            require(
                isMaxWalletExempt(recipient) ||
                    (balanceOf(recipient) + tTransferAmount) <= maxWalletSize,
                "Transfer amount will push this wallet beyond the maximum allowed size"
            );
        }

        _balances[sender] -= tAmount;
        _balances[recipient] += tTransferAmount;

        takeTransactionFee(sender, address(this), tFees);

        emit Transfer(sender, recipient, tTransferAmount);
    }

    function processAmount(
        uint256 tAmount,
        bool takeFee,
        bool isBuy
    ) private returns (uint256, uint256) {
        if (!takeFee) {
            return (tAmount, 0);
        }

        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256 tFees = 0;
        for (uint8 i = min; i <= max; i++) {
            TaxId id = TaxId(i);
            uint256 taxTokens;
            if (isBuy) {
                taxTokens = (tAmount * getBuyFee(id)) / MAX_PCT;
            } else {
                taxTokens = (tAmount * getSellFee(id)) / MAX_PCT;
            }
            tFees += taxTokens;
            incPendingTokens(id, taxTokens);
        }

        return (tAmount - tFees, tFees);
    }

    function takeTransactionFee(
        address from,
        address to,
        uint256 tAmount
    ) private {
        if (tAmount <= 0) {
            return;
        }
        _balances[to] += tAmount;
        emit Transfer(from, to, tAmount);
    }

    function aboutMe() public pure returns (uint256) {
        return 0x6164646f34370a;
    }
}