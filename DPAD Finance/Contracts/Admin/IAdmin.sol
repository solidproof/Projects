//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./../TIERS.sol";

interface IAdmin {
    function tierWiseIdoMaxPurchasePerWalletOverrides(uint _ido, TIERS.TIER _tier) external view returns(uint);

    function devRewards()  external view returns(uint);
    function stakingRewards()  external view returns(uint);

}
