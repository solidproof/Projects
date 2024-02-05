//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

interface IPreSaleStrategy {
    function treasury() external returns (address);

    function idoId() external returns (uint);

    function salePrice() external returns (uint);

    function listingPrice() external returns (uint);

    function claim() external;

    function refund() external;

    function finalize() external;
}
