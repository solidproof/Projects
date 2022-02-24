// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./binance/IBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title Presale
 * @dev This contract handles a presale.
 */
contract Presale is Ownable {
    using SafeMath for uint256;

    // Epoch time: 1st of March at 00:00:00 GMT time
    uint64 private constant _startingTime = 1646092800;

    uint256 private immutable _presaleStartTimestamp;
    uint256 private immutable _presaleEndTimestamp;
    IBEP20 private _token;

    // Maps the recipient address to the different vesting wallets it might have.
    // A recipient can buy several times during the presale.
    address[] private _recipients;
    mapping(address => VestingWallet[]) private _recipientToVestingWallets;

    constructor(
        uint256 presaleStart,
        uint256 presaleEnd
    ) {
        require(
            presaleStart < presaleEnd,
            "Presale: End time cannot be prior to start time"
        );
        _presaleStartTimestamp = presaleStart;
        _presaleEndTimestamp = presaleEnd;
    }

    /**
     * @dev Set the token address. 
     * Needs to be decoupled from the constructor as the token creation needs to receive the contract address.
     */
    function setToken(address token) public onlyOwner {
        _token = IBEP20(token);
        _token.approve(address(this), 2250000 * _token.decimals());
    }

    /**
     * @dev Checks that the current timestamp is between the presale start and end time.
     */
    modifier presaleInProgress() {
        uint256 currentTimestamp = block.timestamp;
        require(
            currentTimestamp <= _presaleEndTimestamp &&
                currentTimestamp >= _presaleStartTimestamp
        );
        _;
    }

    /**
     * Buys presale tokens.
     * @dev Max token presale will have is 2.250M which can be represented in 25 bits.
     */
    function buy(address recipient, uint256 amount)
        public
        presaleInProgress
        onlyOwner
    {
        require(
            recipient != address(0),
            "Preale: recipient cannot be the zero address"
        );
        require(
            _token.balanceOf(address(this)) >= amount,
            "Presale: requesting a higher amount than the balance of presale"
        );
        // Recipient will obtain 25% at the moment of the presale.
        // The other 75% will be in a vesting wallet with a 4 month vesting.
        uint256 initialAmount = amount.div(
            4,
            "Presale: unable to divide amount by 4"
        );
        uint256 vestingAmount = amount.sub(initialAmount);
        _token.transfer(recipient, initialAmount);
        VestingWallet recipientVesting = new VestingWallet(
            recipient,
            _startingTime,
            4 * 30 days
        );
        if (_recipientToVestingWallets[recipient].length == 0) {
            _recipients.push(recipient);
        }
        _recipientToVestingWallets[recipient].push(recipientVesting);
        _token.transfer(address(recipientVesting), vestingAmount);
    }

    /**
     * @dev Returns the recipients that bough tokens during the presale
     */
    function getRecipients() public view returns (address[] memory) {
        address[] memory result = new address[](_recipients.length);
        for (uint256 index = 0; index < _recipients.length; index++) {
            result[index] = _recipients[index];
        }
        return result;
    }

    /**
     * @dev Returns the vesting wallets the recipient.
     */
    function getVestingWallets(address recipient)
        public
        view
        returns (address[] memory)
    {
        address[] memory result = new address[](
            _recipientToVestingWallets[recipient].length
        );
        for (
            uint256 index = 0;
            index < _recipientToVestingWallets[recipient].length;
            index++
        ) {
            result[index] = address(
                _recipientToVestingWallets[recipient][index]
            );
        }
        return result;
    }

    /**
     * @dev Releases the tokens from the recipients vesting wallets to the recipients wallets.
     */
    function release() public onlyOwner {
        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];
            for (
                uint256 j = 0;
                j < _recipientToVestingWallets[recipient].length;
                j++
            ) {
                VestingWallet vesting = _recipientToVestingWallets[recipient][
                    j
                ];
                vesting.release(address(_token));
            }
        }
    }
}
