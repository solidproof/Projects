// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Presale.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract VestingWallets {
    VestingWallet private _developmentVesting;
    VestingWallet private _foundersVesting;
    VestingWallet private _marketingVesting;
    Presale private _presale;

    // Epoch time: 1st of March at 00:00:00 GMT time
    uint64 private constant _startingTime = 1646092800;

    constructor(
        address development,
        address founders,
        address marketing,
        address presale
    ) {
        require(
            development != address(this),
            "VestingWallets: address cannot be the same as the benefitiary"
        );
        require(
            founders != address(this),
            "VestingWallets: address cannot be the same as the benefitiary"
        );
        require(
            marketing != address(this),
            "VestingWallets: address cannot be the same as the benefitiary"
        );
        // 20% vesting per month with initial 20% vested.
        _developmentVesting = new VestingWallet(
            development,
            _startingTime,
            4 * 30 days
        );
        // 10% vesting per month after one year of release.
        _foundersVesting = new VestingWallet(
            founders,
            _startingTime + 365 days,
            10 * 30 days
        );
        // 10% vesting per month with initial 10% vested.
        _marketingVesting = new VestingWallet(
            marketing,
            _startingTime,
            9 * 30 days
        );
        _presale = Presale(presale);
    }

    function getDevelopmentVestingWallet() public view returns (address) {
        return address(_developmentVesting);
    }

    function getFoundersVestingWallet() public view returns (address) {
        return address(_foundersVesting);
    }

    function getMarketingVestingWallet() public view returns (address) {
        return address(_marketingVesting);
    }

    function release(address token) public {
        _developmentVesting.release(token);
        _foundersVesting.release(token);
        _marketingVesting.release(token);
        _presale.release();
    }
}
