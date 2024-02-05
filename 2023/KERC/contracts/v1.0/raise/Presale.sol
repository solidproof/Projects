// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Presale for the KERC token
/// @author snorkypie
/// @custom:security-contact snorkypie@kerc.io
/// @notice Participate in the presale of the KERC token
contract KercPresale is Ownable {
    /// @dev List of valid presale tokens
    address[] public tokens;
    /// @dev Cached token decimals, also used to verify valid token
    mapping(address => uint8) public tokenDecimals;
    /// @dev Address to balance mapping of all presale participants
    mapping(address => uint256) public balanceOf;
    /// @dev List of all presale participants
    address[] public participators;
    /// @dev Receiver of all presale tokens
    address payable public immutable receiver;
    /// @dev Target amount for the presale
    uint256 public targetAmt;
    /// @dev Hard cap amount of the presale, automatically shuts of presale if reached
    uint256 public hardCapAmt;
    /// @dev Unix timestamp representation of when presale starts
    uint256 public startTime;
    /// @dev Unix timestamp representation of when presale ends
    uint256 public endTime;
    /// @dev Flags presale on/off, needed because we can't track hard cap cross chain
    bool public hasEnded;
    /// @dev Total amount contributed (normalised to 18 decimals)
    uint256 public totalContributed;

    event Participate(address indexed user, address token, uint256 amount);
    event UpdatePresaleStartTime(uint256 endTime);
    event UpdatePresaleEndTime(uint256 endTime);
    event PresaleHasEnded(uint256 at);
    event PresaleReopened(uint256 at);
    event Received(address from, uint256 amount);

    function _canParticipate(address _token, uint256 _amount) private view {
        require(open(), "ERR:NOT_OPEN");
        require(_amount > 0, "ERR:AMOUNT");
        require(tokenDecimals[_token] > 0, "ERR:NOT_VALID_TOKEN");
        require(
            totalContributed + _convertToWei(_token, _amount) <= hardCapAmt,
            "ERR:AMT_TOO_BIG"
        );
    }

    modifier canParticipate(address _token, uint256 _amount) {
        _canParticipate(_token, _amount);
        _;
    }

    constructor(
        address payable _receiver,
        address[] memory _tokens,
        uint256 _targetAmt,
        uint256 _hardCapAmt
    ) {
        require(_receiver != address(0), "ERR:ZERO_ADDR:RECEIVER");
        require(
            _targetAmt > 0 && _targetAmt < 1 ether && _targetAmt <= _hardCapAmt,
            "ERR:TARGET"
        );
        require(_hardCapAmt > 0 && _hardCapAmt < 1 ether, "ERR:HARD_CAP");

        setTokens(_tokens);

        receiver = _receiver;
        targetAmt = _targetAmt * 1 ether;
        hardCapAmt = _hardCapAmt * 1 ether;
    }

    function open() public view returns (bool) {
        uint256 ts = block.timestamp;
        return
            !hasEnded &&
            startTime > 0 &&
            endTime > 0 &&
            startTime <= ts &&
            endTime >= ts &&
            totalContributed < hardCapAmt;
    }

    /// @notice Participate in the KERC presale
    /// @dev Regular approval + transfer dance
    function participate(
        address _token,
        uint256 _amount
    ) external canParticipate(_token, _amount) {
        _participate(_token, _amount);
    }

    /// @notice Participate in the KERC presale
    /// @dev Signed permit + transfer
    function participateWithPermit(
        address _token,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external canParticipate(_token, _amount) {
        SafeERC20.safePermit(
            IERC20Permit(_token),
            msg.sender,
            address(this),
            _amount,
            _deadline,
            _v,
            _r,
            _s
        );
        _participate(_token, _amount);
    }

    function _participate(address _token, uint256 _amount) private {
        address user = msg.sender;

        SafeERC20.safeTransferFrom(IERC20(_token), user, receiver, _amount);

        if (balanceOf[user] == 0) {
            participators.push(user);
        }

        /// @dev Normalised to 1e18 since not all tokens have the same decimals
        _amount = _convertToWei(_token, _amount);
        unchecked {
            balanceOf[user] += _amount;
            totalContributed += _amount;
        }

        emit Participate(user, _token, _amount);
    }

    /// @notice List of valid presale tokens
    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    /// @notice Number of unique wallets participating in the presale
    function numberOfParticipants() external view returns (uint256) {
        return participators.length;
    }

    /// @dev Not all stables have 6 decimals so we normalise to 18
    function _convertToWei(
        address _token,
        uint256 _amount
    ) private view returns (uint256) {
        uint8 decimals = tokenDecimals[_token];
        return decimals == 18 ? _amount : _amount * (10 ** (18 - decimals));
    }

    /// @notice Allow flipping hasEnded on and off
    function setHasEnded(bool _hasEnded) external onlyOwner {
        bool currentValue = hasEnded;
        require(currentValue != _hasEnded, "ERR:HAS_ENDED_SAME");

        hasEnded = _hasEnded;

        if (_hasEnded) {
            emit PresaleHasEnded(block.timestamp);
        } else {
            emit PresaleReopened(block.timestamp);
        }
    }

    /// @dev No need to check the target amount since it's display only
    function setTargetAmt(uint256 _targetAmt) external onlyOwner {
        require(_targetAmt < 1 ether, "ERR:AMT");

        targetAmt = _targetAmt * 1 ether;
    }

    /// @dev Allow updating hard cap if bigger than totalContributed
    function setHardCapAmt(uint256 _hardCapAmt) external onlyOwner {
        require(_hardCapAmt < 1 ether, "ERR:AMT");
        require(_hardCapAmt * 1 ether >= totalContributed, "ERR:AMT_TOO_LOW");

        hardCapAmt = _hardCapAmt * 1 ether;
    }

    function setTokens(address[] memory _tokens) public onlyOwner {
        uint256 numTokens = _tokens.length;
        require(numTokens > 0, "ERR:NO_TOKENS");

        /// @dev Reset previously set tokens if we have any
        address[] memory oldTokens = tokens;
        uint256 oldNumTokens = oldTokens.length;
        for (uint256 i; i < oldNumTokens; ) {
            tokenDecimals[oldTokens[i]] = 0;
            unchecked {
                ++i;
            }
        }

        /// @dev Cache new token decimals
        for (uint256 i; i < numTokens; ) {
            address token = _tokens[i];
            require(token != address(0), "ERR:ZERO_ADDR:TOKEN");

            uint8 decimals = ERC20(token).decimals();
            require(decimals > 0 && decimals <= 18, "ERR:DECIMALS");
            tokenDecimals[token] = decimals;

            unchecked {
                ++i;
            }
        }

        tokens = _tokens;
    }

    /// @notice Convenience function for starting the presale
    function setTimes(uint256 _startTime, uint256 _endTime) external onlyOwner {
        uint256 st = startTime;
        uint256 et = endTime;

        require(st == 0 || st > block.timestamp, "ERR:ALREADY_STARTED");
        require(_startTime > 0 && _endTime > 0, "ERR:INPUT_ZERO");
        require(_startTime < _endTime, "ERR:END_LT_START");

        if (st != _startTime) {
            startTime = _startTime;
            emit UpdatePresaleStartTime(_startTime);
        }

        if (et != _endTime) {
            endTime = _endTime;
            emit UpdatePresaleEndTime(_endTime);
        }
    }

    /// @dev End time can only be extended
    function setEndTime(uint256 _endTime) external onlyOwner {
        require(startTime > 0 && _endTime > endTime, "ERR:END_ONLY_EXTEND");

        endTime = _endTime;

        emit UpdatePresaleEndTime(_endTime);
    }

    /// @notice If ETH ends up in this contract
    function withdrawETH() external onlyOwner {
        receiver.transfer(address(this).balance);
    }

    /// @notice If for some reason someone sends ERC20 tokens to this contract
    function withdraw(IERC20 _token) external onlyOwner {
        _token.transfer(receiver, _token.balanceOf(address(this)));
    }
}
