//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

contract PrivateSale {

    // Address => Amount Donated
    mapping ( address => uint256 ) private _donated;

    // List Of All Donors
    address[] private _allDonors;

    // Total Amount Donated
    uint256 private _totalDonated;

    // Receiver Of Donation
    address private _receiver;

    // Terminates Accepting / Tracking BNB
    bool public isTerminated;

    // maximum contribution
    uint256 public max_contribution = 476 * 10**17;

    // creator
    address creator;

    // Donation Event, Trackers Donor And Amount Donated
    event Donated(address donor, uint256 amountDonated, uint256 totalAmountDonated);

    constructor(address receiver) {
        _receiver = receiver;
        creator = msg.sender;
    }

    receive() external payable {
        _process(msg.sender, msg.value);
    }

    function donate() external payable {
        _process(msg.sender, msg.value);
    }

    function terminate() external {
        require(msg.sender == _receiver || msg.sender == creator, 'Only Receiver/Creator');
        isTerminated = true;
    }

    function donated(address user) external view returns(uint256) {
        return _donated[user];
    }

    function allDonors() external view returns (address[] memory) {
        return _allDonors;
    }

    function donorAtIndex(uint256 index) external view returns (address) {
        return _allDonors[index];
    }

    function numberOfDonors() external view returns (uint256) {
        return _allDonors.length;
    }

    function totalDonated() external view returns (uint256) {
        return _totalDonated;
    }

    function _process(address user, uint amount) internal {
        require(
            amount > 0,
            'Zero Value'
        );
        require(
            !isTerminated,
            'Private Sale Is Terminated'
        );

        if (_donated[user] == 0) {
            _allDonors.push(user);
        }

        _donated[user] += amount;
        _totalDonated += amount;

        require(
            _donated[user] <= max_contribution,
            'Exceeds Max Contribution'
        );

        (bool s,) = payable(_receiver).call{value: amount}("");
        require(s);

        emit Donated(user, amount, _donated[user]);
    }
}