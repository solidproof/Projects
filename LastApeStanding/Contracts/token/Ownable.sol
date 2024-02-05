// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

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
    address payable private _devWallet;
    address payable private _marketingWallet;
    address payable private _buybackWallet;

    mapping(address => bool) internal authorizations;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event AuthorizationGranted(address indexed wallet);

    event AuthorizationRevoked(address indexed wallet);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        _owner = initialOwner;
        authorizations[_owner] = true;

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

    function devWallet() public view returns (address payable) {
        return _devWallet;
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
     * @dev Throws if called by any account other than the dev wallet owner.
     */
    modifier onlyDev() {
        require(
            _devWallet == _msgSender(),
            "Ownable: caller is not the dev wallet owner"
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

    function setDevWalletAddress(address payable devWalletAddress)
        public
        virtual
        onlyOwner
    {
        _devWallet = devWalletAddress;
    }

    function setMarketingWalletAddress(address payable marketingWalletAddress)
        public
        virtual
        onlyOwner
    {
        _marketingWallet = marketingWalletAddress;
    }

    function setBuybackWallet(address payable buybackWalletAddress)
        public
        virtual
        onlyOwner
    {
        _buybackWallet = buybackWalletAddress;
    }

    function setLockedLiquidityAddress(address liquidityAddress)
        public
        virtual
        onlyOwner
    {
        require(
            _lockedLiquidity == address(0),
            "Locked liquidity address cannot be changed once set"
        );
        _lockedLiquidity = liquidityAddress;
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

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _owner = newOwner;
        authorizations[newOwner] = true;
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
        require(!authorizations[adr], "Address is already authorized");
        authorizations[adr] = true;

        emit AuthorizationGranted(adr);
    }

    /**
     * Remove address' authorization. Owner only
     */
    function unauthorize(address adr) public onlyOwner {
        require(authorizations[adr], "Address is already NOT authorized");
        authorizations[adr] = false;

        emit AuthorizationRevoked(adr);
    }

    /**
     * Return address' authorization status
     */
    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }
}
