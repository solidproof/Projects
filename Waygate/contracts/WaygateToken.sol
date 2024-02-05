//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./TokenDistributor.sol";

contract WaygateToken is
    TokenDistributor,
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    function initialize(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _totalSupply
    ) external initializer {
        __ERC20_init(_tokenName, _tokenSymbol);
        __Ownable_init();
        __Pausable_init();
        _mint(msg.sender, _totalSupply);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {}

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function addRecipient(address _recipient, uint256 _allocationPercent)
        external
        onlyOwner
    {
        _addReceipient(_recipient, _allocationPercent);
    }

    function removeRecipient(address _recipient) external onlyOwner {
        _removeReceipient(_recipient);
    }

    function distributeTokens() external onlyOwner {
        for (uint8 i = 0; i < recipients.length; i++) {
            if (isRecipient[recipients[i]]) {
                uint256 recipientPercentage = recipientAllocationsPercentage[
                    recipients[i]
                ];
                uint256 amountToTransfer = (totalSupply() *
                    recipientPercentage) / NUMERATOR;
                transfer(recipients[i], amountToTransfer);
            }
        }
    }
}
