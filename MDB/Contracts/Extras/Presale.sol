//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract Presale {

    // Address => Amount Donated
    mapping ( address => uint256 ) private _donated;

    // Whitelisted Users
    mapping ( address => bool ) private _isWhitelisted;

    // List Of All Donors
    address[] private _allDonors;

    // Total Amount Donated
    uint256 private _totalDonated;

    // Receiver Of Donation
    address private _receiver;

    // Terminates Accepting / Tracking BNB
    bool public isTerminated;

    // Presale has started
    bool public isStarted;

    // maximum contribution
    uint256 public max_contribution = 475 * 10**16;

    // maximum reached
    uint256 public hardCap = 1310 * 10**18;

    // minimum amount donated
    uint256 public min_donation = 12 * 10**17;

    // creator
    address creator;
    modifier onlyCreator() {
        require(msg.sender == creator, 'Only Creator');
        _;
    }

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

    function setHardCap(uint256 hardCap_) external onlyCreator {
        hardCap = hardCap_;
    }

    function setMinDonation(uint min_) external onlyCreator {
        min_donation = min_;
    }

    function setMaxContribution(uint max_) external onlyCreator {
        max_contribution = max_;
    }

    function whitelistUsers(address[] calldata users) external onlyCreator {
        for (uint i = 0; i < users.length; i++) {
            _isWhitelisted[
                users[i]
            ] = true;
        }
    }

    function increaseContribution() external onlyCreator {
        max_contribution = 715 * 10**16;
    }

    function terminate() external onlyCreator {
        isTerminated = true;
    }

    function start() external onlyCreator {
        isStarted = true;
    }

    function changeCreator(address creator_) external onlyCreator {
        creator = creator_;
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

    function isWhitelisted(address user) external view returns (bool) {
        return _isWhitelisted[user];
    }

    function _process(address user, uint amount) internal {
        require(
            amount >= min_donation,
            'Minimum Donation Required'
        );
        require(
            !isTerminated,
            'Presale Is Terminated'
        );
        require(
            isStarted,
            'Presale Has Not Started'
        );
        require(
            _isWhitelisted[user],
            'User Not Whitelisted'
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
        require(
            _totalDonated <= hardCap,
            'Hard Cap Reached'
        );

        (bool s,) = payable(_receiver).call{value: address(this).balance}("");
        require(s);

        emit Donated(user, amount, _donated[user]);
    }
}