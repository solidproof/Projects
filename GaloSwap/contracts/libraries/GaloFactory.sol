pragma solidity 0.6.6;

import './interfaces/IGaloFactory.sol';
import './GaloPair.sol';

contract GaloFactory {
    address public owner;
    address public feePercentOwner;
    address public setStableOwner;
    address public feeTo;

    //uint public constant FEE_DENOMINATOR = 100000;
    uint public constant OWNER_FEE_SHARE_MAX = 100000; // 100%
    uint public ownerFeeShare = 50000; // default value = 50%

    uint public constant REFERER_FEE_SHARE_MAX = 20000; // 20%
    mapping(address => uint) public referrersFeeShare; // fees are taken from the user input

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event FeeToTransferred(address indexed prevFeeTo, address indexed newFeeTo);
    event PairCreated(address indexed token0, address indexed token1, address pair, uint length);
    event OwnerFeeShareUpdated(uint prevOwnerFeeShare, uint ownerFeeShare);
    event OwnershipTransferred(address indexed prevOwner, address indexed newOwner);
    event FeePercentOwnershipTransferred(address indexed prevOwner, address indexed newOwner);
    event SetStableOwnershipTransferred(address indexed prevOwner, address indexed newOwner);
    event ReferrerFeeShareUpdated(address referrer, uint prevReferrerFeeShare, uint referrerFeeShare);

    constructor(address feeTo_) public {
        owner = msg.sender;
        feePercentOwner = msg.sender;
        setStableOwner = msg.sender;
        feeTo = feeTo_;

        emit OwnershipTransferred(address(0), msg.sender);
        emit FeePercentOwnershipTransferred(address(0), msg.sender);
        emit SetStableOwnershipTransferred(address(0), msg.sender);
        emit FeeToTransferred(address(0), feeTo_);
    }
    

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner == msg.sender, "GaloFactory: caller is not the owner");
        _;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(GaloPair).creationCode);
    }

    function pairFor(address token0, address token1) external view returns (address pairAddress) {
        pairAddress = getPair[token0][token1];
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'GaloFactory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GaloFactory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'GaloFactory: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(GaloPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(pair != address(0), "GaloFactory: FAILED");
        GaloPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "GaloFactory: zero address");
        emit OwnershipTransferred(owner, _owner);
        owner = _owner;
    }

    function setFeePercentOwner(address _feePercentOwner) external onlyOwner {
        require(_feePercentOwner != address(0), "GaloFactory: zero address");
        emit FeePercentOwnershipTransferred(feePercentOwner, _feePercentOwner);
        feePercentOwner = _feePercentOwner;
    }

    function setSetStableOwner(address _setStableOwner) external {
        require(msg.sender == setStableOwner, "GaloFactory: not setStableOwner");
        require(_setStableOwner != address(0), "GaloFactory: zero address");
        emit SetStableOwnershipTransferred(setStableOwner, _setStableOwner);
        setStableOwner = _setStableOwner;
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        emit FeeToTransferred(feeTo, _feeTo);
        feeTo = _feeTo;
    }

    /**
     * @dev Updates the share of fees attributed to the owner
     *
     * Must only be called by owner
     */
    function setOwnerFeeShare(uint newOwnerFeeShare) external onlyOwner {
        require(newOwnerFeeShare > 0, "GaloFactory: ownerFeeShare mustn't exceed minimum");
        require(newOwnerFeeShare <= OWNER_FEE_SHARE_MAX, "GaloFactory: ownerFeeShare mustn't exceed maximum");
        emit OwnerFeeShareUpdated(ownerFeeShare, newOwnerFeeShare);
        ownerFeeShare = newOwnerFeeShare;
    }

    /**
     * @dev Updates the share of fees attributed to the given referrer when a swap went through him
     *
     * Must only be called by owner
     */
    function setReferrerFeeShare(address referrer, uint referrerFeeShare) external onlyOwner {
        require(referrer != address(0), "GaloFactory: zero address");
        require(referrerFeeShare <= REFERER_FEE_SHARE_MAX, "GaloFactory: referrerFeeShare mustn't exceed maximum");
        emit ReferrerFeeShareUpdated(referrer, referrersFeeShare[referrer], referrerFeeShare);
        referrersFeeShare[referrer] = referrerFeeShare;
    }

    function feeInfo() external view returns (uint _ownerFeeShare, address _feeTo) {
        _ownerFeeShare = ownerFeeShare;
        _feeTo = feeTo;
    }
}