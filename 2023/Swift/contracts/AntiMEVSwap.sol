// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IWETH is IERC20Upgradeable {
    function deposit() external payable;
    function withdraw(uint wad) external payable;
}

contract AntiMEVSwap is Initializable, ReentrancyGuardUpgradeable {
    address public feeReceiver;
    uint256 public feeAmount;
    address public bribeFeeReceiver;
    uint256 public bribeFeeAmount;
    uint256 public constant RESOLUTION = 10000;

    address public supervisor;

    modifier onlySupervisor() {
        require(msg.sender == supervisor || supervisor == address(0), "Forbidden");
        _;
    }

    function AntiMEVSwap_init() external initializer {
        __AntiMEVSwap_init();
        __ReentrancyGuard_init();

        // init code here
        supervisor = msg.sender;
        feeReceiver = msg.sender;
        feeAmount = 10 ** 15; // 0.001 ETH
        bribeFeeReceiver = msg.sender;
        bribeFeeAmount = 10 ** 16; // 0.01 ETH
    }

    function setSupervisor(address newSupervisor) external onlySupervisor {
        require(newSupervisor != supervisor, "Duplicate");
        require(newSupervisor != address(0), "Unable to set to null");

        supervisor = newSupervisor;
    }

    function setFeeInfo(address newReceiver, uint256 newAmount) external onlySupervisor {
        require(newReceiver != address(0), "Unable to set to null address");
        require(newAmount <= 10 ** 17, "< 0.1 ETH");
        feeReceiver = newReceiver;
        feeAmount = newAmount;
    }

    function setBribeFeeInfo(address newReceiver, uint256 newAmount) external onlySupervisor {
        require(newReceiver != address(0), "Unable to set to null address");
        require(newAmount <= 10 ** 18, "< 1 ETH");
        bribeFeeReceiver = newReceiver;
        bribeFeeAmount = newAmount;
    }

    function __AntiMEVSwap_init() internal onlyInitializing {
    }

    function approveMax(address token, address router) external payable nonReentrant {
        // IERC20Upgradeable(token).approve(router, type(uint256).max); // failed for USDT on ethereum because it checks payload size by onlyPayloadSize modifier
        (bool success, ) = token.call(abi.encodeWithSignature("approve(address,uint256)", router, type(uint256).max));
        require(success, "failed to approveMax");
    }

    function approveFinite(address token, address router, uint256 amount) external payable nonReentrant {
        // IERC20Upgradeable(token).approve(router, amount); // failed for USDT on ethereum because it checks payload size by onlyPayloadSize modifier
        (bool success, ) = token.call(abi.encodeWithSignature("approve(address,uint256)", router, amount));
        require(success, "failed to approveFinite");
    }

    function depositToken(address token, uint256 amount) external payable nonReentrant {
        // IERC20Upgradeable(token).transferFrom(msg.sender, address(this), amount); // failed for USDT on ethereum because it checks payload size by onlyPayloadSize modifier
        (bool success, ) = token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount));
        require(success, "failed to transferFrom");
    }

    function withdrawToken(address token, uint256 amount) public payable nonReentrant {
        (bool success, ) = token.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount));
        require(success, "failed to transfer");
    }

    function sweepETH() external payable nonReentrant returns (uint256) {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        return success == true? feeAmount: 0;
    }

    function sweepToken(address token) external payable returns (uint256) {
        uint256 bal = IERC20Upgradeable(token).balanceOf(address(this));
        if (bal > 0) {
            withdrawToken(token, bal);
        }
        return bal;
    }

    function wrapETH(address weth, uint256 amount) external payable nonReentrant {
        if (amount == 0) amount = address(this).balance;

        if (amount > 0) {
            IWETH(weth).deposit{value: amount}();
        }
    }

    function unwrapETH(address weth, uint256 amount) external payable nonReentrant {
        if (amount == 0) {
            amount = IWETH(weth).balanceOf(address(this));
        }
        IWETH(weth).withdraw(amount);
    }

    // 0x00000000 + masked of [ca, calldata] + mask
    function analyzeMessage(bytes calldata cdata) internal returns (bytes4) {
        uint256 i;
        bytes memory bt = cdata[0:4];

        bytes4 sig = bytes4(bt);
        if (sig == 0) {
            (, bytes memory alldata, bytes32 mask) = abi.decode(cdata, (bytes4, bytes, bytes32));

            bytes memory decoded;
            uint256 totallen = alldata.length;
            uint256 loopsa = (totallen + 31) / 32;

            assembly {
                let m := mload(0x40)
                mstore(0x40, add(add(m, 0x20), totallen))

                mstore(m, totallen)
                for { let idx := 0 } lt(idx, loopsa) { idx := add(1, idx) } {
                    mstore(
                        add(add(m, 32), mul(32, idx)),
                        xor(
                            mload(add(add(alldata, 32), mul(32, idx))),
                            mask
                        )
                    )
                }
                decoded := m
            }

            (bytes[] memory t1) = abi.decode(decoded, (bytes[]));

            for (i = 0; i < t1.length; i ++) {
                (address ca, bytes memory data, uint256 useValue) = abi.decode(t1[i], (address, bytes, uint256));
                if (ca == address(0)) {
                    _executeDelegateCall(address(this), data);
                } else {
                    _executeExternalCall(ca, useValue, data);
                }
            }

            return sig;
        } else if (sig == bytes4("\x00\x00\x00\x01")) {
            (, bytes[] memory t1) = abi.decode(cdata, (bytes4, bytes[]));

            for (i = 0; i < t1.length; i ++) {
                (address ca, bytes memory data, uint256 useValue) = abi.decode(t1[i], (address, bytes, uint256));
                if (ca == address(0)) {
                    _executeDelegateCall(address(this), data);
                } else {
                    _executeExternalCall(ca, useValue, data);
                }
            }

            return sig;
        } else if (sig == bytes4("\x00\x00\x00\x02")) {
            (, bytes memory alldata, bytes32 mask) = abi.decode(cdata, (bytes4, bytes, bytes32));

            bytes memory decoded;
            uint256 totallen = alldata.length;
            uint256 loopsa = (totallen + 31) / 32;

            assembly {
                let m := mload(0x40)
                mstore(0x40, add(add(m, 0x20), totallen))

                mstore(m, totallen)
                for { let idx := 0 } lt(idx, loopsa) { idx := add(1, idx) } {
                    mstore(
                        add(add(m, 32), mul(32, idx)),
                        xor(
                            mload(add(add(alldata, 32), mul(32, idx))),
                            mask
                        )
                    )
                }
                decoded := m
            }

            (uint256 coinbase, bytes[] memory t1) = abi.decode(decoded, (uint256, bytes[]));
            if (coinbase > 0) {
                address payable bribee = block.coinbase;
                (bool success, ) = bribee.call{value: coinbase}("");
                require(success, "Can't bribe");

                if (bribeFeeAmount > 0) {
                    payFee(bribeFeeReceiver, bribeFeeAmount);
                }
            }

            for (i = 0; i < t1.length; i ++) {
                (address ca, bytes memory data, uint256 useValue, bytes[] memory modifyList) = abi.decode(t1[i], (address, bytes, uint256, bytes[]));

                uint256 j;
                for (j = 0; j < modifyList.length; j ++) {
                    (uint32 startidx, uint32 endidx, address mca, bytes memory mdata) = abi.decode(modifyList[j], (uint32, uint32, address, bytes));
                    bytes memory mret;
                    if (mca == address(0)) {
                        mret = _executeDelegateCall(address(this), mdata);
                    } else {
                        mret = _executeExternalCall(mca, 0, mdata);
                    }

                    uint32 sidx;

                    for (sidx = 0; sidx < mret.length && sidx + startidx < endidx; sidx ++) {
                        data[startidx + sidx] = mret[sidx];
                    }
                }

                if (ca == address(0)) {
                    _executeDelegateCall(address(this), data);
                } else {
                    _executeExternalCall(ca, useValue, data);
                }
            }

            return sig;
        } else if (sig == bytes4("\x00\x00\x00\x03")) {
            (, uint256 coinbase, bytes[] memory t1) = abi.decode(cdata, (bytes4, uint256, bytes[]));
            if (coinbase > 0) {
                address payable bribee = block.coinbase;
                (bool success, ) = bribee.call{value: coinbase}("");
                require(success, "Can't bribe");

                if (bribeFeeAmount > 0) {
                    payFee(bribeFeeReceiver, bribeFeeAmount);
                }
            }

            for (i = 0; i < t1.length; i ++) {
                (address ca, bytes memory data, uint256 useValue, bytes[] memory modifyList) = abi.decode(t1[i], (address, bytes, uint256, bytes[]));

                uint256 j;
                for (j = 0; j < modifyList.length; j ++) {
                    (uint32 startidx, uint32 endidx, address mca, bytes memory mdata) = abi.decode(modifyList[j], (uint32, uint32, address, bytes));
                    bytes memory mret;
                    if (mca == address(0)) {
                        mret = _executeDelegateCall(address(this), mdata);
                    } else {
                        mret = _executeExternalCall(mca, 0, mdata);
                    }

                    uint32 sidx;

                    for (sidx = 0; sidx < mret.length && sidx + startidx < endidx; sidx ++) {
                        data[startidx + sidx] = mret[sidx];
                    }
                }

                if (ca == address(0)) {
                    _executeDelegateCall(address(this), data);
                } else {
                    _executeExternalCall(ca, useValue, data);
                }
            }

            return sig;
        } else {
            return bytes4("\xff\xff\xff\xff");
        }
    }

    function executeDelegateCall(address ca, bytes memory data) external payable returns(bytes memory retdata) {
        retdata = _executeDelegateCall(ca, data);
    }

    function _delegate(address implementation, bytes memory data) internal virtual returns(bool result, bytes memory retdata) {
        assembly {
            result := delegatecall(gas(), implementation, add(data, 0x20), mload(data), 0, 0)

            let retsize := returndatasize()
            retdata := mload(0x40)
            mstore(retdata, retsize)
            returndatacopy(add(retdata, 0x20), 0, retsize)
            mstore(0x40, add(add(retdata, 0x20), retsize))
/*
            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
            */
        }
    }

    function _executeDelegateCall(address ca, bytes memory data) internal returns(bytes memory result) {
        bool success;
        (success, result) = _delegate(ca, data);
        if (!success) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (result.length < 68) revert("delegatecall error");
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }
    }

    function executeExternalCall(address ca, uint256 value, bytes memory data) external payable nonReentrant returns (bytes memory) {
        return _executeExternalCall(ca, value, data);
    }

    function _executeExternalCall(address ca, uint256 value, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory result) = ca.call{value: value}(data);

        if (!success) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (result.length < 68) revert("call error");
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }

        return result;
    }

    fallback() external payable {
        bytes4 sig = analyzeMessage(msg.data);

        if (sig == bytes4(0) || sig == bytes4("\x00\x00\x00\x01") || sig == bytes4("\x00\x00\x00\x02") || sig == bytes4("\x00\x00\x00\x03")) {
            uint256 value = msg.value;
            require (value >= feeAmount, "Insufficient fee amount");
            if (feeAmount > 0) {
                value -= payFee(feeReceiver, feeAmount);
            }
        }
    }

    receive() external payable {
    }

    function payFee(address _addr, uint256 _amount) internal returns(uint256) {
        (bool success, ) = payable(_addr).call{value: _amount}("");
        require(success, "Can't charge fee");
        return _amount;
    }
}