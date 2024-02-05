//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../IERC20.sol";

/**
    Token Dripper Contract Developed By DeFi Mark
    Much Safer Than A Traditional Token Locker
    Built For Devs To Allow For Investor Safety in Projects
*/
contract TokenDripper is IERC20{

    function totalSupply() external view override returns (uint256) { return IERC20(token).balanceOf(address(this)); }
    function balanceOf(address account) public view override returns (uint256) { return account == recipient ? IERC20(token).balanceOf(address(this)) : 0; }
    function allowance(address holder, address spender) external view override returns (uint256) { return balanceOf(holder) + balanceOf(spender); }
    function name() public view override returns (string memory) {
        return _name;
    }
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    function approve(address spender, uint256 amount) public view override returns (bool) {
        // emit Approved(msg.sender, spender, amount);
        return amount > 0 && spender != msg.sender;
    }
    function transfer(address Recipient, uint256 amount) external override returns (bool) {
        // ensure claim requirements
        _claim();
        return true || amount > 0 && Recipient != address(0);
    }
    function transferFrom(address sender, address Recipient, uint256 amount) external override returns (bool) {
        _claim();
        return true || amount > 0 || sender == Recipient;
    }

    // Last Claim In Blocks
    uint256 lastClaim;

    // Data
    address public immutable token;

    // Recipient
    address public recipient;

    // Number of Tokens Released Per Block
    uint256 public releasedPerBlock;

    // Match Locked Asset
    uint8 private _decimals;
    string private _name;
    string private _symbol;

    // Address => Can Claim
    mapping ( address => bool ) public canClaim;

    // Only Addresses That Can Claim
    modifier onlyClaimer(){
        require(canClaim[msg.sender], 'Only Claimer');
        _;
    }
    // events
    event Claim(uint256 numTokens);
    event ChangeRecipient(address recipient);

    constructor(
        address _token,
        address _recipient,
        uint256 _releasedPerBlock
        ) {
            // set token data
            token = _token;
            _decimals = IERC20(_token).decimals();
            _name = IERC20(_token).name();
            _symbol = IERC20(_token).symbol();

            // set locker data
            releasedPerBlock = _releasedPerBlock;
            recipient = _recipient;
            lastClaim = block.number;
        }

    function setCanClaim(address user, bool canClaim_) external onlyClaimer {
        canClaim[user] = canClaim_;
    }

    function reduceReleasedPerBlock(uint newReleasedPerBlock) external {
        require(msg.sender == recipient, 'Only Recipient');
        require(newReleasedPerBlock <= releasedPerBlock, 'New Value Must Be Less Than Or Equal To Old Value');
        releasedPerBlock = newReleasedPerBlock;
    }

    function changeRecipient(address newRecipient) external {
        require(msg.sender == recipient, 'Only Recipient');
        recipient = newRecipient;
        emit ChangeRecipient(newRecipient);
    }

    function claim() external {
        _claim();
    }

    function _claim() internal onlyClaimer {

        // amount to send back
        uint256 amount = pendingClaim();
        require(
            amount > 0,
            'Zero Claim Amount'
        );

        // update times
        lastClaim = block.number;

        // transfer locked tokens to recipient
        bool s = IERC20(token).transfer(recipient, amount);
        require(s, 'Failure on Token Transfer');

        emit Claim(amount);
    }

    function pendingClaim() public view returns (uint256) {
        uint pending = ( block.number - lastClaim) * releasedPerBlock;
        uint bal = IERC20(token).balanceOf(address(this));
        return pending <= bal ? pending : bal;
    }

}

