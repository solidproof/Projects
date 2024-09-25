// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CutoshiToken is ERC20, AccessControl{

    bool deployed = false;

    constructor(address[] memory _whitelist, uint256[] memory _values, address _owner) ERC20("CutoshiToken", "CUTO"){
        // require(_whitelist.length == _values.length, "CutoshiToken: address and value array don't match");
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(DEFAULT_ADMIN_ROLE, address(this));

        for(uint i = 0; i < _whitelist.length; i++) {
            mint(_whitelist[i], _values[i]*10**18);
        }

        deployed = true;
    }

    function mint(address to, uint256 amount) public {
        if(deployed) {
            require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || address(this) == msg.sender, "CutoshiToken::mint: You do not have the role for minting new tokens!");
        }

        
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "CutoshiToken::burn: You do not have the role for burning tokens!");
        _burn(from, amount);
    }

}