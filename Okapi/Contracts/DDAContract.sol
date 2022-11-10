// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract DDAContract is AccessControl {

    enum CharityType {
        CHARITY,
        FUNDRAISER
    }

    struct Catalog {
        string vip;
        string website;
        string name;
        string email;
        string country;
        string summary;
        string detail;
        string photo;
        string title;
        string location;
    }
    struct CharityStruct {
        address walletAddress;
        CharityType charityType;
        uint256 fund;
        Catalog catalog;
    }

    struct AdminStruct {
        address walletAddress;
        string name;
    }

    address public immutable SWAP_ROUTER_ADDRESS;
    address public immutable SWAP_FACTOR_ADDRESS;
    address public immutable WETH_ADDRESS;
    address public immutable USDT_ADDRESS;
    address public immutable OKAPI_ADDRESS;

    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant CHARITY_ROLE = keccak256("CHARITY_ROLE");
    bytes32 private constant BLACK_ROLE = keccak256("BLACK_ROLE");

    CharityStruct[] public charities;
    AdminStruct[] public adminUsers;

    modifier notBlackRole() {
        require(!hasRole(BLACK_ROLE, msg.sender), "Current wallet is in black list");
        _;
    }

    event Donate(
        address indexed _from,
        address indexed _to,
        address indexed _currency,
        uint256 amount,
        uint256 timestamp
    );

    event CreateCharity(
        address walletAddress,
        CharityType charityType,
        Catalog catalog,
        uint256 fund,
        uint256 timestamp
    );

    event BlackCharity(
        address indexed walletAddress,
        address indexed adminAddress,
        uint256 timestamp
    );

    event AddAdmin(
        address indexed walletAddress,
        string name,
        uint256 timestamp
    );

    event RemoveAdmin(
        address indexed walletAddress,
        uint256 timestamp
    );

    constructor(address _admin, address _swapRouter, address _weth, address _usdt, address _okapi) {
        require(_admin != address(0), 'Admin address can not be zero.');
        require(_swapRouter != address(0), 'Admin address can not be zero.');
        require(_weth != address(0), 'WETH address can not be zero.');
        require(_usdt != address(0), 'USDT address can not be zero.');

        SWAP_ROUTER_ADDRESS = _swapRouter;
        WETH_ADDRESS = _weth;
        USDT_ADDRESS = _usdt;
        OKAPI_ADDRESS = _okapi;
        SWAP_FACTOR_ADDRESS = IUniswapV2Router02(SWAP_ROUTER_ADDRESS).factory();

        _setupRole(OWNER_ROLE, _admin);
        _setupRole(ADMIN_ROLE, _admin);
    }

    /**
     * @notice This function will send donation to (_to)th index of charities and buy Okapi token
     * @param _to : the index of charity on charities list
     * @param _currency : the cryptocurrency address of donation
     * @param _amount : the amount of cryptocurrency : wei
    */
    function donate(uint256 _to, address _currency, uint256 _amount) external notBlackRole {
        IERC20 currency = IERC20(_currency);
        require (_amount > 100 wei, "The amount must be bigger than 100 wei!");
        require (currency.balanceOf(msg.sender) > _amount, "Not have enough tokens!");
        require (hasRole(CHARITY_ROLE, charities[_to].walletAddress), "FundRaiser's address isn't registered!");

        uint256 price = 1 ether;
        if (_currency == USDT_ADDRESS)
            price = 1 ether;
        else{
            address pairAddress = IUniswapV2Factory(SWAP_FACTOR_ADDRESS).getPair(USDT_ADDRESS, _currency);
            require (pairAddress != address(0), 'There is no pool between your token and usdt');
            price = getTokenPrice(pairAddress, _currency, 1 ether);
        }
        uint256 usdtAmount = _amount * price / 1 ether;
        uint256 ratio = 100;

        if (usdtAmount >= 250000 ether) {
            ratio = 1;
        } else if (usdtAmount >= 100000 ether) {
            ratio = 3;
        } else if (usdtAmount >= 50000 ether) {
            ratio = 5;
        } else if (usdtAmount >= 10000 ether) {
            ratio = 7;
        }
        uint256 transferAmount = _amount * (10000 - ratio) / 10000;
        uint256 buyAmount = _amount - transferAmount;
        charities[_to].fund = charities[_to].fund + transferAmount * price / 1 ether;
        currency.transferFrom(msg.sender, charities[_to].walletAddress, transferAmount);
        swap(_currency, OKAPI_ADDRESS, buyAmount, 0, msg.sender);
        emit Donate(msg.sender, charities[_to].walletAddress, _currency, transferAmount, block.timestamp);
    }

    /**
     * @notice This function will create charity and store it to charities list
     * @param _type : 0 (CHARITY), 1 (FUNDRAISER)
     * @param _catalog : information of charity [vip, website, name, email, country, summary, detail, photo, title, location]
    */
    function createCharity(CharityType _type, Catalog calldata _catalog) external notBlackRole {
        require(!hasRole(ADMIN_ROLE, msg.sender), "Current wallet is in admin list");
        require(!hasRole(CHARITY_ROLE, msg.sender), "Current wallet is in charity list");
        require( bytes(_catalog.email).length > 0 &&
                 bytes(_catalog.country).length > 0 &&
                 bytes(_catalog.summary).length > 0 &&
                 bytes(_catalog.detail).length > 0 &&
                 bytes(_catalog.name).length > 0,
                 'There is empty string passed as parameter');

        charities.push(CharityStruct({
            walletAddress: msg.sender,
            charityType: _type,
            catalog: _catalog,
            fund:0
        }));
        _setupRole(CHARITY_ROLE, msg.sender);
        emit CreateCharity(msg.sender, _type, _catalog, 0,  block.timestamp);
    }

    /**
     * @notice This function will remove charity and set it as black charity to block on this contract
     * @param index: index of charity on charities list
     */
    function blackCharity(uint index) external onlyRole(ADMIN_ROLE) {
        require(charities.length > index, 'That charity is not existed!');
        address userAddress = charities[index].walletAddress;
        uint i;
        for(i = index + 1; i < charities.length; i++) {
            charities[i-1] = charities[i];
        }
        charities.pop();
        _revokeRole(CHARITY_ROLE, userAddress);
        _setupRole(BLACK_ROLE, userAddress);
        emit BlackCharity(userAddress, msg.sender, block.timestamp);
    }

    /**
     * @notice This function will create admin and store it to adminUser list
     * @param _newAddress : new adminUser's addresss
     * @param _name : name of adminUser
    */
    function addAdmin(address _newAddress, string memory _name) external onlyRole(OWNER_ROLE) {
        require(!hasRole(ADMIN_ROLE, _newAddress), 'This address already has admin role');
        require(!hasRole(CHARITY_ROLE, _newAddress), 'This address is in charity list');
        require(!hasRole(BLACK_ROLE, _newAddress), 'This address is in black list');

        adminUsers.push(AdminStruct({
            walletAddress: _newAddress,
            name: _name
        }));
        _setupRole(ADMIN_ROLE, _newAddress);
        emit AddAdmin(_newAddress, _name, block.timestamp);
    }

    /**
     * @notice This function will remove ADMIN_ROLE of adminUser's selected index
     * @param index: index of adminUser on adminUsers list
     */
    function removeAdmin(uint index) external onlyRole(OWNER_ROLE) {
        require(adminUsers.length > index, 'That address is not existed!');

        address userAddress = adminUsers[index].walletAddress;
        require(!hasRole(OWNER_ROLE, userAddress), 'Owner can not be removed from admin list');
        uint i;
        for(i = index + 1; i < adminUsers.length; i++) {
            adminUsers[i-1] = adminUsers[i];
        }
        adminUsers.pop();
        _revokeRole(ADMIN_ROLE, userAddress);
        emit RemoveAdmin(userAddress, block.timestamp);
    }
    function getCharities() public view returns (CharityStruct[] memory){
        return charities;
    }

    function getAdminUsers() public view returns (AdminStruct[] memory){
        return adminUsers;
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOutMin, address _to) public {
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);

        IERC20(_tokenIn).approve(SWAP_ROUTER_ADDRESS, _amountIn);

        address[] memory path;
        path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        IUniswapV2Router02(SWAP_ROUTER_ADDRESS).swapExactTokensForTokens(_amountIn, _amountOutMin, path, _to, block.timestamp + 60);
    }

    function getTokenPrice(address pairAddress, address currency, uint amount) internal view returns(uint)
    {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint Res0, uint Res1,) = pair.getReserves();
        if(pair.token1() == currency)
            return((amount*Res0)/Res1);
        else
            return((amount*Res1)/Res0);
    }
}