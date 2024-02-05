// SPDX-License-Identifier: Unlicensed
// ZeroSum contract

pragma solidity ^0.8.7;
import {Pausable} from "./Pausable.sol";
import {ITreasury} from "./interfaces/ITreasury.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {Address} from "./utils/Address.sol";


contract FeeProvider is Pausable {
    using Address for address;
// +++++++++ Fee Managment ++++++++++
    struct FeeMeta {
        uint16 baseFee; // Cumulitve fees, platform fee = baseFee - Sum(fractions)
        address[] beneficiaries;
        uint16[] fractions;
    }

    address public platformWallet;
    uint16 public baseFee;
    uint16 constant bpDec = 10000;
    mapping(uint16 => FeeMeta) _feeMetas;

    function constructFeeProvider(address token_, address treasury_, address wallet, uint16 baseFee_) public virtual onlyOwner {
        _setTreasury(treasury_);
        platformWallet = wallet;
        baseFee = baseFee_;
        token = token_;
    }

    function setPlatformWallet(address wallet) external onlyAdminHierarchy(AdminRole.Developer) {
        platformWallet = wallet;
        emit PlatformWalletUpgraded(msg.sender, wallet);
    }

    function _getFees(uint16 feeType) internal view returns(uint16) {
        if(feeType == 0) return baseFee;
        return _feeMetas[feeType].baseFee;
    }

    function _sendFees(uint16 feeType, uint256 amount) internal { // amount is whole pool
        if(feeType == 0) {
            _giveToken(platformWallet, (amount * baseFee) / bpDec);
            return;
        }
        FeeMeta storage feeMeta = _feeMetas[feeType];
        uint length = feeMeta.beneficiaries.length;
        uint sum = (amount * feeMeta.baseFee) / bpDec;
        for(uint i = 0; i < length; i++) {
            uint fee = (feeMeta.fractions[i] * amount) / bpDec;
            sum -= fee;
            _giveToken(feeMeta.beneficiaries[i], fee);
        }
        _giveToken(platformWallet, sum);
    }

    function setBaseFees(uint16 baseFee_) external onlyAdminHierarchy(AdminRole.Developer) {
        require(baseFee_ <= bpDec / 4, "FeeProvider: baseFee must be no more than 25%");
        baseFee = baseFee_;
        emit BaseFeeChanged(baseFee_);
    }

    function setFeeType(uint16 feeType, FeeMeta calldata feeMeta) external onlyAdminHierarchy(AdminRole.Developer) {
        require(feeType != 0, "FeeProvider: zero feeType is immutable");
        require(feeMeta.beneficiaries.length == feeMeta.fractions.length, "FeeProvider: invalid feeMeta lenght");
        require(feeMeta.baseFee <= bpDec, "FeeProvider: baseFee must be no more than 100%");
        uint sum = 0;
        for(uint i = 0; i < feeMeta.beneficiaries.length; i++) {
            sum += feeMeta.fractions[i];
        }
        require(sum <= feeMeta.baseFee, "FeeProvider: fraction fee sum more than baseFee");
        _feeMetas[feeType] = feeMeta;
        emit FeeTypeAdded(feeType, feeMeta.baseFee, feeMeta.beneficiaries, feeMeta.fractions);
    }
// ++++++++++ Token Manipulations ++++++++++
    address public token;
    ITreasury public treasury;

    function setToken(address token_) external onlyAdminHierarchy(AdminRole.Developer) {
        require(token_.isContract(), "FeeProvider: Token must be a contract");
        token = token_;
        emit TokenUpgraded(token_);
    }

    function setTreasury(address treasury_) external onlyAdminHierarchy(AdminRole.Developer) {
        require(treasury_.isContract(), "FeeProvider: Treasury must be a contract");
        _setTreasury(treasury_);
        emit TreasuryUpgraded(treasury_);
    }

    function _setTreasury(address treasury_) internal {
        treasury = ITreasury(treasury_);
    }

    function _takeToken(address from, uint256 amount) internal {
        if(amount == 0) return;
        TransferHelper.safeTransferFrom(token, from, address(treasury), amount);
    }

    function _giveToken(address to, uint256 amount) internal {
        if(amount == 0) return;
        // bytes4(keccak256(bytes('withdraw(address,address,uint256)')));
        (bool success, bytes memory data) = address(treasury).call(abi.encodeWithSelector(0xd9caed12, token, to, amount));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'FeeProvider::_giveToken: transfer failed'
        );
    }
// ++++++++++ Events ++++++++++
    event PlatformWalletUpgraded(address indexed admin, address indexed wallet);
    event BaseFeeChanged(uint16 baseFee);
    event FeeTypeAdded(uint16 indexed feeType, uint16 indexed baseFee, address[] beneficiaries, uint16[] fractions);
    event TokenUpgraded(address token);
    event TreasuryUpgraded(address treasury);
}
