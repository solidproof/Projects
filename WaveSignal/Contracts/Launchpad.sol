// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import "./structs/SharedStructs.sol";
import "./interfaces/IWaveLock.sol";
import "./interfaces/IWaveERC20.sol";


contract Launchpad is Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IWaveERC20;

    mapping(address => bool) public whiteListUsers;
    mapping(address => bool) public superAccounts;

    modifier onlyWhiteListUser() {
        require(whiteListUsers[msg.sender], "Only Admin");
        _;
    }

    modifier onlySuperAccount() {
        require(superAccounts[msg.sender], "Only Super");
        _;
    }

    modifier onlyRunningPool() {
        require(state == 1, "Not available pool");
        _;
    }

    function adminWhiteListUsers(address _user, bool _whiteList) public onlySuperAccount {
        whiteListUsers[_user] = _whiteList;
    }

    function _check(address _tokenA, address _tokenB, address _routerAddress, address _factoryAddress) internal view returns (bool) {
        address pair;
        IUniswapV2Router02 routerObj = IUniswapV2Router02(_routerAddress);
        IUniswapV2Factory factoryObj = IUniswapV2Factory(_factoryAddress);

        if (_tokenB == address(0)) {
            pair = factoryObj.getPair(address(_tokenA), routerObj.WETH());
        } else {
            pair = factoryObj.getPair(address(_tokenA), address(_tokenB));
        }
        if(pair == address (0)) {
            return true;
        }
        return IWaveERC20(pair).totalSupply() == 0;
    }

    function check() external view returns (bool) {
        return _check(address(icoToken), feeToken, routerAddress, factoryAddress);
    }

    IWaveERC20 public icoToken;
    address public feeToken; //BUSD, BNB
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public presaleRate; // 1BNB or BUSD ~ presaleRate
    uint256 public minInvest;
    uint256 public maxInvest;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public poolType; //0 burn, 1 refund
    uint256 public whitelistPool;  //0 public, 1 whitelist, 2 public anti bot
    address public holdingToken;
    uint256 public holdingTokenAmount;

    // contribute vesting
    uint256 public cliffVesting; //First gap release after listing (minutes)
    uint256 public lockAfterCliffVesting; //second gap release after cliff (minutes)
    uint256 public firstReleasePercent; // 0 is not vesting
    uint256 public vestingPeriodEachCycle; //0 is not vesting
    uint256 public tokenReleaseEachCycle; //percent: 0 is not vesting

    //team vesting
    uint256 public teamTotalVestingTokens; // if > 0, lock
    uint256 public teamCliffVesting; //First gap release after listing (minutes)
    uint256 public teamFirstReleasePercent; // 0 is not vesting
    uint256 public teamVestingPeriodEachCycle; // 0 is not vesting
    uint256 public teamTokenReleaseEachCycle; //percent: 0 is not vesting

    uint256 public listingTime;

    uint256 public state; // 1 running||available, 2 finalize, 3 cancel
    uint256 public raisedAmount; // 1 running, 2 cancel
    address public signer;
    uint256 public constant ZOOM = 10_000;
    uint256 public penaltyFee = 1000;

    // dex
    address public factoryAddress;
    address public routerAddress;
    uint256 public listingPrice;
    uint256 public listingPercent; //1 => 10000
    uint256 public lpLockTime; //seconds

    IWaveLock public waveLock;
    uint256 public teamLockId;
    uint256 public lpLockId;

    //fee
    uint256 public raisedFeePercent; //BNB With Raised Amount
    uint256 public raisedTokenFeePercent;

    address payable public fundAddress;
    uint256 public totalSoldTokens;

    address public deadAddress = address(0x0000dead);


    struct JoinInfo {
        uint256 totalInvestment;
        uint256 claimedTokens;
        uint256 totalTokens;
        bool refund;
    }

    mapping(address => JoinInfo) public joinInfos;


    event Invest(address investor, uint value, uint tokens);
    event Buy(uint256 indexed _saleId, uint256 indexed _quantity, uint256 indexed _price, address _buyer, address _seller);
    event UpdateSaleQuantity(uint256 indexed _saleId, address indexed _seller, uint256 indexed _quantity, uint256 _status);
    event UpdateSalePrice(uint256 indexed _saleId, address indexed _seller, uint256 indexed _price);
    event CancelListed(uint256 indexed _saleId, address indexed _receiver);
    event List(uint indexed _saleId, uint256 indexed _price, uint256 indexed _quantity, address _owner, uint256 _tokenId, uint256 status);
    event TokenClaimed(address _address, uint256 tokensClaimed);


    function setFundAddress(address payable _fundAddress) public onlySuperAccount {
        fundAddress = _fundAddress;
    }

    function setSigner(address _signer) public onlySuperAccount {
        signer = _signer;
    }

    function setPenaltyFee(uint256 _penaltyFee) public onlySuperAccount {
        penaltyFee = _penaltyFee;
    }


    function setDex(address _factory, address _router) public onlySuperAccount {
        factoryAddress = _factory;
        routerAddress = _router;
    }

    constructor(SharedStructs.LaunchpadInfo memory info, SharedStructs.ClaimInfo memory userClaimInfo, SharedStructs.TeamVestingInfo memory teamVestingInfo, SharedStructs.DexInfo memory dexInfo, SharedStructs.FeeSystem memory feeInfo, SharedStructs.SettingAccount memory settingAccount) {

        require(info.icoToken != address(0), 'Invalid token');
        require(info.presaleRate > 0, 'Invalid presale rate');
        require(info.softCap < info.hardCap, 'Invalid cap');
        require(info.startTime < info.endTime, 'Invalid time');
        require(info.minInvest < info.maxInvest, 'Invalid investment');
        require(dexInfo.listingPercent <= ZOOM, 'Invalid listing');
        require(userClaimInfo.firstReleasePercent + userClaimInfo.tokenReleaseEachCycle <= ZOOM, 'Invalid user vst');
        require(teamVestingInfo.teamFirstReleasePercent + teamVestingInfo.teamTokenReleaseEachCycle <= ZOOM, 'Invalid team vst');
        require(_check(info.icoToken, info.feeToken, dexInfo.routerAddress, dexInfo.factoryAddress), 'LP Added!');


        icoToken = IWaveERC20(info.icoToken);
        feeToken = info.feeToken;
        softCap = info.softCap;
        hardCap = info.hardCap;
        presaleRate = info.presaleRate;
        minInvest = info.minInvest;
        maxInvest = info.maxInvest;
        startTime = info.startTime;
        endTime = info.endTime;
        whitelistPool = info.whitelistPool;
        poolType = info.poolType;

        cliffVesting = userClaimInfo.cliffVesting;
        lockAfterCliffVesting = userClaimInfo.lockAfterCliffVesting;
        firstReleasePercent = userClaimInfo.firstReleasePercent;
        vestingPeriodEachCycle = userClaimInfo.vestingPeriodEachCycle;
        tokenReleaseEachCycle = userClaimInfo.tokenReleaseEachCycle;

        teamTotalVestingTokens = teamVestingInfo.teamTotalVestingTokens;
        if (teamTotalVestingTokens > 0) {
            require(teamVestingInfo.teamFirstReleasePercent > 0 &&
            teamVestingInfo.teamVestingPeriodEachCycle > 0 &&
            teamVestingInfo.teamTokenReleaseEachCycle > 0 &&
                teamVestingInfo.teamFirstReleasePercent + teamVestingInfo.teamTokenReleaseEachCycle <= ZOOM);
            teamCliffVesting = teamVestingInfo.teamCliffVesting;
            teamFirstReleasePercent = teamVestingInfo.teamFirstReleasePercent;
            teamVestingPeriodEachCycle = teamVestingInfo.teamVestingPeriodEachCycle;
            teamTokenReleaseEachCycle = teamVestingInfo.teamTokenReleaseEachCycle;
        }


        routerAddress = dexInfo.routerAddress;
        factoryAddress = dexInfo.factoryAddress;
        listingPrice = dexInfo.listingPrice;
        listingPercent = dexInfo.listingPercent;
        lpLockTime = dexInfo.lpLockTime;

        raisedFeePercent = feeInfo.raisedFeePercent;
        raisedTokenFeePercent = feeInfo.raisedTokenFeePercent;
        penaltyFee = feeInfo.penaltyFee;


        state = 1;
        whiteListUsers[settingAccount.deployer] = true;
        whiteListUsers[settingAccount.superAccount] = true;
        superAccounts[settingAccount.superAccount] = true;
        signer = settingAccount.signer;
        fundAddress = settingAccount.fundAddress;
        transferOwnership(settingAccount.deployer);
        waveLock = IWaveLock(settingAccount.waveLock);
    }

    function calculateUserTotalTokens(uint256 _amount) private view returns (uint256) {
        uint256 feeTokenDecimals = 18;
        if (feeToken != address(0)) {
            feeTokenDecimals = IWaveERC20(feeToken).decimals();
        }
        return _amount.mul(presaleRate).div(10 ** feeTokenDecimals);
    }

    function contribute(uint256 _amount, bytes calldata _sig) external payable whenNotPaused onlyRunningPool {
        require(startTime <= block.timestamp && endTime >= block.timestamp, 'Invalid time');
        if (whitelistPool == 1) {
            bytes32 message = prefixed(keccak256(abi.encodePacked(
                    _msgSender(),
                    address(this)
                )));

            require(recoverSigner(message, _sig) == signer, 'not in wl');
        } else if (whitelistPool == 2) {
            require(IWaveERC20(holdingToken).balanceOf(_msgSender()) >= holdingTokenAmount, 'Insufficient holding');
        }
        JoinInfo storage joinInfo = joinInfos[_msgSender()];
        require(joinInfo.totalInvestment.add(_amount) >= minInvest && joinInfo.totalInvestment.add(_amount) <= maxInvest, 'Invalid amount');
        require(raisedAmount.add(_amount) <= hardCap, 'Meet hard cap');


        joinInfo.totalInvestment = joinInfo.totalInvestment.add(_amount);

        uint256 newTotalSoldTokens = calculateUserTotalTokens(_amount);
        totalSoldTokens = totalSoldTokens.add(newTotalSoldTokens);
        joinInfo.totalTokens = joinInfo.totalTokens.add(newTotalSoldTokens);
        joinInfo.refund = false;

        raisedAmount = raisedAmount.add(_amount);


        if (feeToken == address(0)) {
            require(msg.value >= _amount, 'Invalid Amount');
        } else {
            IWaveERC20 feeTokenErc20 = IWaveERC20(feeToken);
            feeTokenErc20.safeTransferFrom(_msgSender(), address(this), _amount);
        }

    }


    function cancelLaunchpad() external onlyWhiteListUser onlyRunningPool {
        state = 3;
    }


    function setWhitelistPool(uint256 _wlPool, address _holdingToken, uint256 _amount) external onlyWhiteListUser {
        require(_wlPool < 2 ||
            (_wlPool == 2 && _holdingToken != address(0) && IWaveERC20(_holdingToken).totalSupply() > 0 && _amount > 0), 'Invalid setting');
        holdingToken = _holdingToken;
        holdingTokenAmount = _amount;
        whitelistPool = _wlPool;
    }

    function finalizeLaunchpad() external onlyWhiteListUser onlyRunningPool {
        require(block.timestamp > startTime, 'Not start');
        require(_check(address(icoToken), feeToken, routerAddress, factoryAddress), 'LP Added!');

        if (block.timestamp < endTime) {
            require(raisedAmount >= hardCap, 'Cant finalize');
        }
        if (block.timestamp >= endTime) {
            require(raisedAmount >= softCap, 'Not meet soft cap');
        }
        state = 2;
        listingTime = block.timestamp;

        IUniswapV2Router02 routerObj = IUniswapV2Router02(routerAddress);
        IUniswapV2Factory factoryObj = IUniswapV2Factory(factoryAddress);
        uint256 feeTokenDecimals = 18;
        if (feeToken != address(0)) {
            feeTokenDecimals = IWaveERC20(feeToken).decimals();
        }
        uint256 totalRaisedFeeTokens = raisedAmount.mul(presaleRate).mul(raisedTokenFeePercent).div(10 ** feeTokenDecimals).div(ZOOM);

        uint256 totalRaisedFee = raisedAmount.mul(raisedFeePercent).div(ZOOM);

        uint256 totalFeeTokensToAddLP = (raisedAmount.sub(totalRaisedFee)).mul(listingPercent).div(ZOOM);
        uint256 totalFeeTokensToOwner = raisedAmount.sub(totalRaisedFee).sub(totalFeeTokensToAddLP);
        uint256 icoTokenToAddLP = totalFeeTokensToAddLP.mul(listingPrice).div(10 ** feeTokenDecimals);
        icoToken.approve(routerAddress, icoTokenToAddLP);

        uint256 icoLaunchpadBalance = icoToken.balanceOf(address(this));
        uint256 totalRefundOrBurnTokens = icoLaunchpadBalance.sub(icoTokenToAddLP).sub(totalSoldTokens).sub(totalRaisedFeeTokens).sub(teamTotalVestingTokens);

        if (totalRaisedFeeTokens > 0) {
            icoToken.safeTransfer(fundAddress, totalRaisedFeeTokens);
        }

        if (totalRefundOrBurnTokens > 0) {
            if (poolType == 0) {
                icoToken.safeTransfer(deadAddress, totalRefundOrBurnTokens);
            } else {
                icoToken.safeTransfer(owner(), totalRefundOrBurnTokens);
            }
        }

        address pair;
        uint liquidity;

        if (feeToken == address(0)) {
            if (totalFeeTokensToOwner > 0) {
                payable(owner()).transfer(totalFeeTokensToOwner);
            }
            if (totalRaisedFee > 0) {
                payable(fundAddress).transfer(totalRaisedFee);
            }
            (,, liquidity) = routerObj.addLiquidityETH{value : totalFeeTokensToAddLP}(
                address(icoToken),
                icoTokenToAddLP,
                0,
                0,
                address(this),
                block.timestamp);
            pair = factoryObj.getPair(address(icoToken), routerObj.WETH());
        } else {
            if (totalFeeTokensToOwner > 0) {
                IWaveERC20(feeToken).safeTransfer(owner(), totalFeeTokensToOwner);
            }
            if (totalRaisedFee > 0) {
                IWaveERC20(feeToken).safeTransfer(fundAddress, totalRaisedFee);
            }


            IWaveERC20(feeToken).approve(routerAddress, totalFeeTokensToAddLP);
            (,, liquidity) = routerObj.addLiquidity(
                address(icoToken),
                address(feeToken),
                icoTokenToAddLP,
                totalFeeTokensToAddLP,
                0,
                0,
                address(this),
                block.timestamp
            );
            pair = factoryObj.getPair(address(icoToken), address(feeToken));
        }
        require(pair != address(0), 'Invalid pair');
        require(liquidity > 0, 'Invalid Liquidity!');
        if (lpLockTime > 0) {
            IWaveERC20(pair).approve(address(waveLock), liquidity);
            uint256 unlockDate = block.timestamp + lpLockTime;
            lpLockId = waveLock.lock(owner(), pair, true, liquidity, unlockDate, 'LP');

        } else {
            IWaveERC20(pair).safeTransfer(owner(), liquidity);
        }

        if (teamTotalVestingTokens > 0) {
            icoToken.approve(address(waveLock), teamTotalVestingTokens);
            teamLockId = waveLock.vestingLock(
                owner(),
                address(icoToken),
                false,
                teamTotalVestingTokens,
                listingTime.add(teamCliffVesting),
                teamFirstReleasePercent,
                teamVestingPeriodEachCycle,
                teamTokenReleaseEachCycle,
                'TEAM');
        }
    }

    function claimCanceledTokens() external onlyWhiteListUser {
        require(state == 3, 'Not cancel');
        uint256 balance = icoToken.balanceOf(address(this));
        require(balance > 0, "Claimed");
        if (balance > 0) {
            icoToken.safeTransfer(_msgSender(), balance);
        }
    }

    function emergencyWithdrawPool(address _token, uint256 _amount) external onlySuperAccount {
        require(_amount > 0, 'Invalid amount');
        if (_token == address(0)) {
            payable(_msgSender()).transfer(_amount);
        }
        else {
            IWaveERC20 token = IWaveERC20(_token);
            token.safeTransfer(_msgSender(), _amount);
        }
    }


    function withdrawContribute() external whenNotPaused {
        JoinInfo storage joinInfo = joinInfos[_msgSender()];
        require((state == 3) || (raisedAmount < softCap && block.timestamp > endTime));
        require(joinInfo.refund == false, 'Refunded');
        require(joinInfo.totalInvestment > 0, 'Not Invest');

        uint256 totalWithdraw = joinInfo.totalInvestment;
        joinInfo.refund = true;
        joinInfo.totalTokens = 0;
        joinInfo.totalInvestment = 0;

        raisedAmount = raisedAmount.sub(totalWithdraw);

        totalSoldTokens = totalSoldTokens.sub(joinInfo.totalTokens);

        if (feeToken == address(0)) {
            payable(_msgSender()).transfer(totalWithdraw);
        } else {
            IWaveERC20 feeTokenErc20 = IWaveERC20(feeToken);

            require(feeTokenErc20.balanceOf(address(this)) >= totalWithdraw, 'Insufficient Balance');
            feeTokenErc20.safeTransfer(_msgSender(), totalWithdraw);
        }
    }

    function emergencyWithdrawContribute() external whenNotPaused onlyRunningPool {
        JoinInfo storage joinInfo = joinInfos[_msgSender()];
        require(startTime <= block.timestamp && endTime >= block.timestamp, 'Invalid time');
        require(joinInfo.refund == false, 'Refunded');
        require(joinInfo.totalInvestment > 0, 'Not contribute');

        uint256 penalty = joinInfo.totalInvestment.mul(penaltyFee).div(ZOOM);
        uint256 refundTokens = joinInfo.totalInvestment.sub(penalty);
        raisedAmount = raisedAmount.sub(joinInfo.totalInvestment);
        totalSoldTokens = totalSoldTokens.sub(joinInfo.totalTokens);

//        uint256 totalPenaltyFeeToOwner = penalty.mul(ownerPenaltyFeePercent).div(ZOOM);
//        uint256 totalPenaltyFeeToFund = penalty.sub(totalPenaltyFeeToOwner);


        joinInfo.refund = true;
        joinInfo.totalTokens = 0;
        joinInfo.totalInvestment = 0;

        require(refundTokens > 0, 'Invalid rf amount');

        if (feeToken == address(0)) {
            if (refundTokens > 0) {
                payable(_msgSender()).transfer(refundTokens);
            }
//            if (totalPenaltyFeeToOwner > 0) {
//                payable(owner()).transfer(totalPenaltyFeeToOwner);
//            }
            if (penalty > 0) {
                payable(fundAddress).transfer(penalty);
            }

        } else {
            IWaveERC20 feeTokenErc20 = IWaveERC20(feeToken);

//            require(feeTokenErc20.balanceOf(address(this)) >= refundTokens, 'Insufficient Balance');
            if (refundTokens > 0) {
                feeTokenErc20.safeTransfer(_msgSender(), refundTokens);
            }
//            if (totalPenaltyFeeToOwner > 0) {
//                feeTokenErc20.safeTransfer(owner(), totalPenaltyFeeToOwner);
//            }
            if (penalty > 0) {
                feeTokenErc20.safeTransfer(fundAddress, penalty);
            }
        }
    }


    function claimTokens() external whenNotPaused {
        JoinInfo storage joinInfo = joinInfos[_msgSender()];
        require(joinInfo.claimedTokens < joinInfo.totalTokens, "Claimed");
        require(state == 2, "Not finalize");
        require(joinInfo.refund == false, "Refunded!");


        uint256 claimableTokens = _getUserClaimAble(joinInfo);
        require(claimableTokens > 0, 'Zero token');

        uint256 claimedTokens = joinInfo.claimedTokens.add(claimableTokens);
        joinInfo.claimedTokens = claimedTokens;
        icoToken.safeTransfer(_msgSender(), claimableTokens);
    }

    function getUserClaimAble(address _sender) external view returns (uint256) {
        JoinInfo storage joinInfo = joinInfos[_sender];
        return _getUserClaimAble(joinInfo);
    }


    function _getUserClaimAble(JoinInfo memory joinInfo)
    internal
    view
    returns (uint256)
    {
        uint256 claimableTokens = 0;
        if (state != 2 || joinInfo.totalTokens == 0 || joinInfo.refund == true || joinInfo.claimedTokens >= joinInfo.totalTokens || block.timestamp < listingTime + cliffVesting) {
            return claimableTokens;
        }
        uint256 currentTotal = 0;
        if (firstReleasePercent == 0) {
            currentTotal = joinInfo.totalTokens;
        } else {
            uint256 tgeReleaseAmount = joinInfo.totalTokens.mul(firstReleasePercent).div(ZOOM);
            uint256 cycleReleaseAmount = joinInfo.totalTokens.mul(tokenReleaseEachCycle).div(ZOOM);
            uint256 time = 0;
            uint256 firstVestingTime = listingTime + cliffVesting + lockAfterCliffVesting;
            if (block.timestamp >= firstVestingTime) {
                time = ((block.timestamp.sub(firstVestingTime)).div(firstVestingTime)).add(1);
            }

            currentTotal = (time.mul(cycleReleaseAmount)).add(tgeReleaseAmount);
            if (currentTotal > joinInfo.totalTokens) {
                currentTotal = joinInfo.totalTokens;
            }
        }

        claimableTokens = currentTotal.sub(joinInfo.claimedTokens);
        return claimableTokens;
    }


    function getLaunchpadInfo() external view returns (SharedStructs.LaunchpadReturnInfo memory) {
        uint256 balance = icoToken.balanceOf(address(this));

        SharedStructs.LaunchpadReturnInfo memory result;
        result.softCap = softCap;
        result.hardCap = hardCap;
        result.startTime = startTime;
        result.endTime = endTime;
        result.state = state;
        result.raisedAmount = raisedAmount;
        result.balance = balance;
        result.feeToken = feeToken;
        result.listingTime = listingTime;
        result.whitelistPool = whitelistPool;
        result.holdingToken = holdingToken;
        result.holdingTokenAmount = holdingTokenAmount;
        return result;
    }

    function getOwnerZoneInfo(address _user) external view returns (SharedStructs.OwnerZoneInfo memory) {
        SharedStructs.OwnerZoneInfo memory result;
        bool isOwner = _user == owner();
        if (!isOwner) {
            return result;
        }
        result.isOwner = isOwner;
        result.whitelistPool = whitelistPool;

        // if false => true,
        result.canCancel = state == 1;
        result.canFinalize = state == 1 &&
        ((block.timestamp < endTime && raisedAmount >= hardCap) ||
        (block.timestamp >= endTime && raisedAmount >= softCap));
        return result;
    }


    function pause() public onlyWhiteListUser whenNotPaused {
        _pause();
    }

    function unpause() public onlyWhiteListUser whenPaused {
        _unpause();
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
        keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
    }

    function recoverSigner(bytes32 message, bytes memory sig)
    internal
    pure
    returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function splitSignature(bytes memory sig)
    internal
    pure
    returns (
        uint8,
        bytes32,
        bytes32
    )
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
        // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
        // second 32 bytes
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

}


