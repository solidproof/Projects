/**
 * @title Interface Referrals
 * @dev IReferrals contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity ^0.8.0;

interface IReferrals {
    function getSponsor(address _account) external view returns (address);

    function isMember(address _user) external view returns (bool);

    function addMember(address _member, address _parent) external;

    function membersList(uint256 _id) external view returns (address);

    function getListReferrals(address _member)
        external
        view
        returns (address[] memory);
}