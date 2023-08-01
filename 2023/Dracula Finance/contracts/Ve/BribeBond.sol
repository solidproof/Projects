// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/IVe.sol";
import "../interface/IVoter.sol";
import "../interface/IMinter.sol";
import "../interface/IPair.sol";
import "../Reentrancy.sol";
import "../interface/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BribeBond is Ownable, Reentrancy {
    uint8 public immutable stableDecimals;
    IERC20 public immutable stable;

    IERC20 public fang;
    IVoter public draculaVoter;
    IVe public ve;
    IMinter public minter;

    address public poolFang;

    uint256 public percentSupply;

    /// @dev day => deposited Fang value in a day
    uint256[7] public depositedFangForDay;

    event DepositBond(
        address user,
        uint256 activePeriod,
        uint256 valueStable,
        uint256 valueFangBond
    );
    event ClaimBondRewards(address user, uint256 tokenId, uint256 claimed);

    event NewPercentSupply(uint256 percent);
    event NewPoolFang(address pool);
    event ResetDepositedFangForEpoch();

    constructor(IVoter _draculaVoter, IMinter _minter, IERC20 _stable) {
        IVe _ve = IVe(_draculaVoter.ve());
        require(address(_draculaVoter) != address(0), "voter address zero ");
        require(address(_minter) != address(0), "minter address zero ");
        require(address(_ve) != address(0), "voter address zero ");
        require(address(_stable) != address(0), "stable address zero ");
        draculaVoter = _draculaVoter;
        ve = _ve;
        fang = IERC20(ve.token());
        minter = _minter;
        stable = _stable;
        stableDecimals = _stable.decimals();
        percentSupply = 200; //0.5%
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @notice get limit bond per day
    function limitPerDay() public view returns (uint256) {
        return
            (fang.totalSupply() - fang.balanceOf(address(ve))) / percentSupply;
    }

    /// @notice get deposited fang for each days of the current epoch
    function getDepositedFangForDays()
        external
        view
        returns (uint256[7] memory)
    {
        return depositedFangForDay;
    }

    /// @notice get fang price in stable price at 10**18
    function getFangPrice() public view returns (uint256, uint256) {
        (uint112 reserve0, uint112 reserve1, ) = IPair(poolFang).getReserves();
        uint256 decimalsDelta = uint256(18 - stableDecimals);
        address token0 = IPair(poolFang).token0();
        uint256 price;
        if (token0 == address(stable)) {
            /// @dev reserve0 == stable
            price = decimalsDelta > 0
                ? (reserve0 * 10 ** (decimalsDelta + 18)) / reserve1
                : (reserve0 * 10 ** 18) / reserve1;
        } else {
            /// @dev reserve1 == stable
            price = decimalsDelta > 0
                ? (reserve1 * 10 ** (decimalsDelta + 18)) / reserve0
                : (reserve1 * 10 ** 18) / reserve0;
        }
        return (price, decimalsDelta);
    }

    /// @notice get fang value for the rate of amount stable
    /// @param amountStable of stable to convert
    function getFangValue(uint256 amountStable) public view returns (uint256) {
        (uint256 _price, uint256 _decimalsDelta) = getFangPrice();

        return (amountStable * 10 ** (18 + _decimalsDelta)) / _price;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            EXTERNALS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /// @notice Deposit stable to get a veFANG Bond
    /// @param _value of stable to deposit
    function depositBond(uint256 _value) external lock {
        require(!draculaVoter.isLocked(), "deposit bond locked!");
        require(poolFang != address(0), "pool fang not set!");
        require(_value > 0, "amount 0 stable");
        uint256 _activePeriod = minter.activePeriod(); /// @dev each Thursday at 00:00 UTC
        require(
            !draculaVoter.isSnapshot(_activePeriod),
            "period not updated yet"
        );

        /// @dev get day of the current epoch
        uint256 dayOfEpoch = ((block.timestamp - (_activePeriod - 1 weeks)) /
            1 days);

        /// @dev get fang value
        uint256 valueFang = getFangValue(_value);
        require(valueFang > 0, "amount 0 fang");

        uint256 newDepositedFangForDay = depositedFangForDay[dayOfEpoch] +
            valueFang;

        require(
            newDepositedFangForDay <= limitPerDay(),
            "limit per day reached!"
        );

        /// @dev add valueFang for the current day
        depositedFangForDay[dayOfEpoch] += valueFang; /// @dev deleted when snapshot is ended

        /// @dev mint nft with value fang +15%
        uint256 valueFangBond = valueFang + ((valueFang * 15) / 100);
        ve.createLockBond(valueFangBond, msg.sender);

        /// @dev transfer stable
        stable.transferFrom(msg.sender, address(this), _value);

        emit DepositBond(msg.sender, _activePeriod, _value, valueFangBond);
    }

    /// @notice Claim stable rewards from deposits on the previous epoch in function of the vote share for each gauges
    /// @param gauges [] of gauges to claim
    /// @param tokenId to redeem
    function claimBondRewards(
        address[] memory gauges,
        uint256 tokenId
    ) external lock {
        require(ve.isApprovedOrOwner(msg.sender, tokenId), "!owner");
        /// @dev calculate bond rewards
        uint256 claimable = draculaVoter._claimBondRewards(gauges, tokenId);

        require(claimable > 0, "no bond rewards");

        stable.transfer(msg.sender, claimable);

        emit ClaimBondRewards(msg.sender, tokenId, claimable);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER & VOTER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function setPercentSupply(uint256 _percentSupply) external onlyOwner {
        percentSupply = _percentSupply;
        emit NewPercentSupply(_percentSupply);
    }

    function setPoolFang(address _poolFang) external onlyOwner {
        require(_poolFang != address(0), "address zero");
        poolFang = _poolFang;
        emit NewPoolFang(_poolFang);
    }

    function resetDepositedValueForEpoch() external {
        require(msg.sender == address(draculaVoter), "not voter");
        delete depositedFangForDay;
        emit ResetDepositedFangForEpoch();
    }

    function withdraw(IERC20 _token) external onlyOwner {
        require(_token != stable, "cannot withdraw stable");
        _token.transfer(msg.sender, _token.balanceOf(address(this)));
    }
}
