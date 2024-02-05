// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/IFactory.sol";
import "./DraculaPair.sol";

contract DraculaFactory is IFactory {
    bool public override isPaused;
    address public pauser;
    address public pendingPauser;
    address public immutable override treasury;

    mapping(address => mapping(address => mapping(bool => address)))
        public
        override getPair;
    address[] public allPairs;
    /// @dev Simplified check if its a pair, given that `stable` flag might not be available in peripherals
    mapping(address => bool) public override isPair;

    address internal _temp0;
    address internal _temp1;
    bool internal _temp;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        bool stable,
        address pair,
        uint256 allPairsLength
    );

    constructor(address _treasury) {
        pauser = msg.sender;
        isPaused = false;
        treasury = _treasury;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function setPauser(address _pauser) external {
        require(msg.sender == pauser, "DraculaFactory: Not pauser");
        pendingPauser = _pauser;
    }

    function acceptPauser() external {
        require(
            msg.sender == pendingPauser,
            "DraculaFactory: Not pending pauser"
        );
        pauser = pendingPauser;
    }

    function setPause(bool _state) external {
        require(msg.sender == pauser, "DraculaFactory: Not pauser");
        isPaused = _state;
    }

    function setSwapFee(address pair, uint256 value) external {
        require(msg.sender == pauser, "DraculaFactory: Not pauser");
        DraculaPair(pair).setSwapFee(value);
    }

    function pairCodeHash() external pure override returns (bytes32) {
        return keccak256(type(DraculaPair).creationCode);
    }

    function getInitializable()
        external
        view
        override
        returns (address, address, bool)
    {
        return (_temp0, _temp1, _temp);
    }

    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external override returns (address pair) {
        require(tokenA != tokenB, "DraculaFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "DraculaFactory: ZERO_ADDRESS");
        require(
            getPair[token0][token1][stable] == address(0),
            "DraculaFactory: PAIR_EXISTS"
        );
        // notice salt includes stable as well, 3 parameters
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable));
        (_temp0, _temp1, _temp) = (token0, token1, stable);
        pair = address(new DraculaPair{salt: salt}());
        getPair[token0][token1][stable] = pair;
        // populate mapping in the reverse direction
        getPair[token1][token0][stable] = pair;
        allPairs.push(pair);
        isPair[pair] = true;
        emit PairCreated(token0, token1, stable, pair, allPairs.length);
    }

    function getAllPairs() external view returns (address[] memory) {
        return allPairs;
    }
}
