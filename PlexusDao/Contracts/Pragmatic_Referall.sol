    // SPDX-License-Identifier: None

    pragma solidity 0.7.4;

    contract Ownable {
        address private _owner;

        event OwnershipRenounced(address indexed previousOwner);

        event OwnershipTransferred(
            address indexed previousOwner,
            address indexed newOwner
        );

        constructor() {
            _owner = msg.sender;
        }

        function owner() public view returns (address) {
            return _owner;
        }

        modifier onlyOwner() {
            require(msg.sender == _owner, "Not owner");
            _;
        }

        function renounceOwnership() public onlyOwner {
            emit OwnershipRenounced(_owner);
            _owner = address(0);
        }

        function transferOwnership(address newOwner) public onlyOwner {
            _transferOwnership(newOwner);
        }

        function _transferOwnership(address newOwner) internal {
            require(newOwner != address(0), "Zero Address Validation");
            emit OwnershipTransferred(_owner, newOwner);
            _owner = newOwner;
        }
    }

    contract ReferralCA is Ownable {

        //Referrals
        mapping (address => address) private referrer;
        mapping (address => bool) private isReferred;
        mapping (address => address[]) private myReferrals;
        mapping (address => uint256) private referralIncome;

        address public mainCA;


        constructor() {
        }

        // Referral

        function referAsOwner(address _referredBy, address _toRefer) external onlyOwner {
            require(!isReferred[_toRefer], "Already referred");
            isReferred[_toRefer] = true;
            referrer[_toRefer] = _referredBy;
            myReferrals[_referredBy].push(_toRefer);
        }

        function getReferred(address _referredBy) external {
            require(!isReferred[msg.sender], "Already referred");
            require(_referredBy != msg.sender, "Can't refer yourself");
            isReferred[msg.sender] = true;
            referrer[msg.sender] = _referredBy;
            myReferrals[_referredBy].push(msg.sender);
        }


        function setReferStatus(address _referredBy, address _toRefer) external onlyOwner {
            isReferred[_toRefer] = true;
            referrer[_toRefer] = _referredBy;
            myReferrals[_referredBy].push(_toRefer);
        }

        function getNumberOfReferrals(address _address) public view returns(uint256) {
            return myReferrals[_address].length;
        }

        function getReferrer(address _address) public view returns (address) {
            return referrer[_address];
        }

        function getIsReferred(address _address) public view returns (bool) {
            return isReferred[_address];
        }

        function getMyReferrals(address _address) public view returns (address[] memory){
            return myReferrals[_address];
        }


        function getMyReferralIncome(address _address) external view returns (uint256){
            return referralIncome[_address];
        }

        function setMainCA(address _address) external onlyOwner {
            require(_address != address(0), "Zero Address Validation");
            mainCA = _address;
        }

        function updateReferralIncome(address _address, uint256 _income) external {
            require(msg.sender == mainCA,"Not allowed to update");
            referralIncome[_address] = referralIncome[_address] + _income;
        }
    }