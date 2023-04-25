// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BridgeBase is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    uint256 public chainId;
    uint256 index;
    address public BURN_ADDRESS;
    mapping(uint256 => bool) public supportedChainIds;
    mapping(address => mapping(uint256 => bool))
        public supportedTokensToChainId;
    event RequestBridge(
        address indexed _token,
        bytes _toAddr,
        uint256 _amount,
        uint256 _originChainId,
        uint256 _fromChainId,
        uint256 _toChainId,
        uint256 _index
    );

    constructor(uint256[] memory _chainIds) {
        for (uint256 i = 0; i < _chainIds.length; i++) {
            supportedChainIds[_chainIds[i]] = true;
        }
        BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
        index = 1;
    }

    function requestBridge(
        address _tokenAddress,
        bytes memory _toAddr,
        uint256 _amount,
        uint256 _toChainId
    ) public payable nonReentrant {
        require(chainId != _toChainId, "Chain ids must be different");
        require(supportedChainIds[_toChainId], "Unsupported chainId");
        require(
            supportedTokensToChainId[_tokenAddress][_toChainId],
            "Unsupported token"
        );

        safeTransferIn(_tokenAddress, msg.sender, _amount);

        emit RequestBridge(
            _tokenAddress,
            _toAddr,
            _amount,
            _toChainId,
            chainId,
            _toChainId,
            index
        );
        index++;
    }

    function addChainIdSupported(
        uint256 _chainId,
        bool _state
    ) public onlyOwner {
        supportedChainIds[_chainId] = _state;
    }

    function setSupportedToken(
        uint256 _chainId,
        address _token,
        bool _state
    ) public onlyOwner {
        supportedTokensToChainId[_token][_chainId] = _state;
    }

    function safeTransferIn(
        address _token,
        address _from,
        uint256 _amount
    ) internal {
        IERC20 erc20 = IERC20(_token);
        uint256 balBefore = erc20.balanceOf(address(this));
        erc20.transferFrom(_from, address(this), _amount);
        require(
            erc20.balanceOf(address(this)).sub(balBefore) == _amount,
            "!transfer from"
        );
        erc20.transfer(BURN_ADDRESS, _amount);
    }
}