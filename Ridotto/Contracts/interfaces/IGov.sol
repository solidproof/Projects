import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGOV is IERC20 {
    function addMasterChef(address _MC) external;

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function addMinter(address minter) external;

    function transfer(address to, uint256 amount)
        external
        override
        returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool);

    function delegates(address delegator) external view returns (address);

    function delegate(address delegatee) external;

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function getCurrentVotes(address account) external view returns (uint256);

    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        returns (uint256);
}
