// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract RiperToken is ERC20Capped, AccessControlEnumerable {

  // keccak256("MINTER_ROLE")
  bytes32 public constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
  // keccak256("BURNER_ROLE")
  bytes32 public constant BURNER_ROLE = 0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848;

  modifier onlyHasRole(bytes32 _role) {
        require(
            hasRole(_role, _msgSender()),
            "Access denied"
        );
        _;
    }

  constructor(uint256 initialSupply) ERC20("Riper Defi", "RIPER") ERC20Capped(1_000_000_000 * 10 ** 18) {
    // mint token initial supply to deployer
    ERC20._mint(_msgSender(), initialSupply);
    // make the deployer as admin
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function mint(address _to, uint256 _amount)
        external
        onlyHasRole(MINTER_ROLE)
    {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount)
        external
        onlyHasRole(BURNER_ROLE)
    {
        _burn(_from, _amount);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        require(
            _to != address(this),
            "Transfer to self not allowed"
        );
        super._transfer(_from, _to, _amount);
    }

}