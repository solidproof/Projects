// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IStableSwap.sol";
import "./interfaces/IStableSwapLP.sol";
import "./interfaces/IStableSwapDeployer.sol";
import "./interfaces/IStableSwapLPFactory.sol";

contract StableSwapFactory is Ownable {
    struct StableSwapPairInfo {
        address swapContract;
        address token0;
        address token1;
        address LPContract;
    }
    struct StableSwapThreePoolPairInfo {
        address swapContract;
        address token0;
        address token1;
        address token2;
        address LPContract;
    }

    mapping(address => mapping(address => mapping(address => StableSwapThreePoolPairInfo))) public stableSwapPairInfo;
    // Query three pool pair infomation by two tokens.
    mapping(address => mapping(address => StableSwapThreePoolPairInfo)) threePoolInfo;
    mapping(uint256 => address) public swapPairContract;

    IStableSwapLPFactory public immutable LPFactory;
    IStableSwapDeployer public immutable SwapTwoPoolDeployer;
    IStableSwapDeployer public immutable SwapThreePoolDeployer;

    address constant ZEROADDRESS = address(0);

    uint256 public pairLength;

    event NewStableSwapPair(address indexed swapContract, address tokenA, address tokenB, address tokenC, address LP);

    /**
     * @notice constructor
     * _LPFactory: LP factory
     * _SwapTwoPoolDeployer: Swap two pool deployer
     * _SwapThreePoolDeployer: Swap three pool deployer
     */
    constructor(
        IStableSwapLPFactory _LPFactory,
        IStableSwapDeployer _SwapTwoPoolDeployer,
        IStableSwapDeployer _SwapThreePoolDeployer
    ) {
        LPFactory = _LPFactory;
        SwapTwoPoolDeployer = _SwapTwoPoolDeployer;
        SwapThreePoolDeployer = _SwapThreePoolDeployer;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function sortTokens(
        address tokenA,
        address tokenB,
        address tokenC
    )
        internal
        pure
        returns (
            address,
            address,
            address
        )
    {
        require(tokenA != tokenB && tokenA != tokenC && tokenB != tokenC, "IDENTICAL_ADDRESSES");
        address tmp;
        if (tokenA > tokenB) {
            tmp = tokenA;
            tokenA = tokenB;
            tokenB = tmp;
        }
        if (tokenB > tokenC) {
            tmp = tokenB;
            tokenB = tokenC;
            tokenC = tmp;
            if (tokenA > tokenB) {
                tmp = tokenA;
                tokenA = tokenB;
                tokenB = tmp;
            }
        }
        return (tokenA, tokenB, tokenC);
    }


    /**
     * @notice createSwapPair
     * @param tokenA: Addresses of ERC20 conracts .
     * @param tokenB: Addresses of ERC20 conracts .
     * @param A: Amplification coefficient multiplied by n * (n - 1)
     * @param fee: Fee to charge for exchanges
     * @param protocol_fee: Protocol fee
     */
    function createSwapPair(
        address tokenA,
        address tokenB,
        uint256 A,
        uint256 fee,
        uint256 protocol_fee
    ) external onlyOwner {
        require(tokenA != ZEROADDRESS && tokenB != ZEROADDRESS && tokenA != tokenB, "Illegal token");
        (address t0, address t1) = sortTokens(tokenA, tokenB);
        address LP = LPFactory.createSwapLP(t0, t1, ZEROADDRESS, address(this));
        address swapContract = SwapTwoPoolDeployer.createSwapPair(t0, t1, A, fee, protocol_fee, msg.sender, LP);
        IStableSwapLP(LP).setMinter(swapContract);
        addPairInfoInternal(swapContract, t0, t1, ZEROADDRESS, LP);
    }

    /**
     * @notice createThreePoolPair
     * @param tokenA: Addresses of ERC20 conracts .
     * @param tokenB: Addresses of ERC20 conracts .
     * @param tokenC: Addresses of ERC20 conracts .
     * @param A: Amplification coefficient multiplied by n * (n - 1)
     * @param fee: Fee to charge for exchanges
     * @param protocol_fee: Protocol fee
     */
    function createThreePoolPair(
        address tokenA,
        address tokenB,
        address tokenC,
        uint256 A,
        uint256 fee,
        uint256 protocol_fee
    ) external onlyOwner {
        require(
            tokenA != ZEROADDRESS &&
            tokenB != ZEROADDRESS &&
            tokenC != ZEROADDRESS &&
            tokenA != tokenB &&
            tokenA != tokenC &&
            tokenB != tokenC,
            "Illegal token"
        );
        (address t0, address t1, address t2) = sortTokens(tokenA, tokenB, tokenC);
        address LP = LPFactory.createSwapLP(t0, t1, t2, address(this));
        address swapContract = SwapThreePoolDeployer.createSwapPair(t0, t1, t2, A, fee, protocol_fee, msg.sender, LP);
        IStableSwapLP(LP).setMinter(swapContract);
        addPairInfoInternal(swapContract, t0, t1, t2, LP);
    }

    function addPairInfoInternal(
        address swapContract,
        address t0,
        address t1,
        address t2,
        address LP
    ) internal {
        StableSwapThreePoolPairInfo storage info = stableSwapPairInfo[t0][t1][t2];
        info.swapContract = swapContract;
        info.token0 = t0;
        info.token1 = t1;
        info.token2 = t2;
        info.LPContract = LP;
        swapPairContract[pairLength] = swapContract;
        pairLength += 1;
        if (t2 != ZEROADDRESS) {
            addThreePoolPairInfo(t0, t1, t2, info);
        }

        emit NewStableSwapPair(swapContract, t0, t1, t2, LP);
    }

    function addThreePoolPairInfo(
        address t0,
        address t1,
        address t2,
        StableSwapThreePoolPairInfo memory info
    ) internal {
        threePoolInfo[t0][t1] = info;
        threePoolInfo[t0][t2] = info;
        threePoolInfo[t1][t2] = info;
    }

    function addPairInfo(address swapContract) external onlyOwner {
        require(swapContract != ZEROADDRESS, "addPairInfo: Illegal swapContract address");
        IStableSwap swap = IStableSwap(swapContract);
        uint256 N_COINS = swap.N_COINS();
        if (N_COINS == 2) {
            addPairInfoInternal(swapContract, swap.coins(0), swap.coins(1), ZEROADDRESS, swap.token());
        } else if (N_COINS == 3) {
            addPairInfoInternal(swapContract, swap.coins(0), swap.coins(1), swap.coins(2), swap.token());
        }
    }

    function getPairInfo(address tokenA, address tokenB) external view returns (StableSwapPairInfo memory info) {
        (address t0, address t1) = sortTokens(tokenA, tokenB);
        StableSwapThreePoolPairInfo memory pairInfo = stableSwapPairInfo[t0][t1][ZEROADDRESS];
        info.swapContract = pairInfo.swapContract;
        info.token0 = pairInfo.token0;
        info.token1 = pairInfo.token1;
        info.LPContract = pairInfo.LPContract;
    }

    function getThreePoolPairInfo(address tokenA, address tokenB)
        external
        view
        returns (StableSwapThreePoolPairInfo memory info)
    {
        (address t0, address t1) = sortTokens(tokenA, tokenB);
        info = threePoolInfo[t0][t1];
    }
}