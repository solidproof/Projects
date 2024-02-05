// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Issuer {
    /*
     *  Events
     */
    event DealInstantiation(
        address indexed issuer,
        address indexed instantiation,
        uint256 _dealId,
        address indexed dividendVaultAddress
    );
    event AddedToWhitelist(address indexed instantiation);
    event AddedToBlacklist(address indexed instantiation);

    /*
     *  Storage
     */
    mapping(address => bool) public isInstantiation;
    mapping(address => address[]) public instantiations;
    mapping(address => address) public dealIssuer;
    mapping(uint256 => address) public dealIdToAddress;
    mapping(uint256 => address) public dealIdToDividend;

    mapping(address => bool) public whiteListUsers;
    mapping(address => bool) public blackListUsers;

    /*
     *Modifiers
     */
    modifier onlyWhiteListed() {
        require(whiteListUsers[msg.sender], "Only whitelist");
        _;
    }
    modifier notBlacklisted() {
        require(!blackListUsers[msg.sender], "Blacklisted");
        _;
    }


    /// @dev Add address to whitelist.
    /// @param _userAddress Address of investor.
    function _addToWhitelist(address _userAddress) internal {
        whiteListUsers[_userAddress] = true;
        blackListUsers[_userAddress] = false;
        emit AddedToWhitelist(_userAddress);
    }

    /// @dev Add address to blacklist.
    /// @param _userAddress Address of investor.
    function _addToBlacklist(address _userAddress) internal {
        whiteListUsers[_userAddress] = false;
        blackListUsers[_userAddress] = true;
        emit AddedToBlacklist(_userAddress);
    }

    /*
     * Public functions
     */
    /// @dev Returns number of deals by issuer.
    /// @param issuer Contract issuer.
    /// @return Returns number of deals by issuer.
    function getDealsCount(address issuer) external view returns (uint256) {
        return instantiations[issuer].length;
    }

    /// @dev Registers contract in issuer registry.
    /// @param instantiation Address of contract instantiation.
    function _register(
        address instantiation,
        uint256 _dealId,
        address dividendVaultAddress
    ) internal {
        isInstantiation[instantiation] = true;
        instantiations[msg.sender].push(instantiation);
        dealIssuer[instantiation] = msg.sender;
        dealIdToAddress[_dealId] = instantiation;
        dealIdToDividend[_dealId] = dividendVaultAddress;
        emit DealInstantiation(
            msg.sender,
            instantiation,
            _dealId,
            dividendVaultAddress
        );
    }
}
