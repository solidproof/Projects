// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {SemiFungibleVault} from "./SemiFungibleVault.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

/// @author MiguelBits
contract Vault is SemiFungibleVault, ReentrancyGuard {

    using FixedPointMathLib for uint256;
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error AddressZero();
    error AddressNotFactory(address _contract);
    error AddressNotController(address _contract);
    error MarketEpochDoesNotExist();
    error EpochAlreadyStarted();
    error EpochNotFinished();
    error FeeMoreThan150(uint256 _fee);
    error ZeroValue();
    error OwnerDidNotAuthorize(address _sender, address _owner);
    error EpochEndMustBeAfterBegin();
    error MarketEpochExists();
    error FeeCannotBe0();

    /*///////////////////////////////////////////////////////////////
                               IMMUTABLES AND STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable tokenInsured;
    address public treasury;
    int256 public immutable strikePrice;
    address public immutable factory;
    address public controller;

    uint256[] public epochs;

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => uint256) public idFinalTVL;
    mapping(uint256 => uint256) public idClaimTVL;
    // @audit uint32 for timestamp is enough for the next 80 years
    mapping(uint256 => uint256) public idEpochBegin;
    // @audit id can be uint32
    mapping(uint256 => bool) public idEpochEnded;
    // @audit id can be uint32
    mapping(uint256 => bool) public idExists;
    mapping(uint256 => uint256) public epochFee;
    mapping(uint256 => bool) public epochNull;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /** @notice Only factory addresses can call functions that use this modifier
      */
    modifier onlyFactory() {
        if(msg.sender != factory)
            revert AddressNotFactory(msg.sender);
        _;
    }

    /** @notice Only controller addresses can call functions that use this modifier
      */
    modifier onlyController() {
        if(msg.sender != controller)
            revert AddressNotController(msg.sender);
        _;
    }

    /** @notice Only market addresses can call functions that use this modifier
      */
    modifier marketExists(uint256 id) {
        if(idExists[id] != true)
            revert MarketEpochDoesNotExist();
        _;
    }

    /** @notice You can only call functions that use this modifier before the current epoch has started
      */
    modifier epochHasNotStarted(uint256 id) {
        if(block.timestamp > idEpochBegin[id])
            revert EpochAlreadyStarted();
        _;
    }

    /** @notice You can only call functions that use this modifier after the current epoch has started
      */
    modifier epochHasEnded(uint256 id) {
        if(idEpochEnded[id] == false)
            revert EpochNotFinished();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
        @notice constructor
        @param  _assetAddress    token address representing your asset to be deposited;
        @param  _name   token name for the ERC1155 mints. Insert the name of your token; Example: Sugar_USDC_1.2$
        @param  _symbol token symbol for the ERC1155 mints. insert here if saltish or caramel + Symbol. Example: CaramelSugar or saltishSugar;
        @param  _token  address of the oracle to lookup the price in chainlink oracles;
        @param  _strikePrice    uint256 representing the price to trigger the depeg event;
        @param _controller  address of the controller contract, this contract can trigger the depeg events;
     */
    constructor(
        address _assetAddress,
        string memory _name,
        string memory _symbol,
        address _treasury,
        address _token,
        int256 _strikePrice,
        address _controller
    ) SemiFungibleVault(ERC20(_assetAddress), _name, _symbol) {

        if(_treasury == address(0))
            revert AddressZero();

        if(_controller == address(0))
            revert AddressZero();

        if(_token == address(0))
            revert AddressZero();

        tokenInsured = _token;
        treasury = _treasury;
        strikePrice = _strikePrice;
        factory = msg.sender;
        controller = _controller;
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Deposit function from ERC4626, with payment of a fee to a treasury implemented;
        @param  id  uint256 in UNIX timestamp, representing the end date of the epoch. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1654038000;
        @param  assets  uint256 representing how many assets the user wants to deposit, a fee will be taken from this value;
        @param receiver  address of the receiver of the assets provided by this function, that represent the ownership of the deposited asset;
     */
    function deposit(
        uint256 id,
        uint256 assets,
        address receiver
    )
        public
        override
        marketExists(id)
        epochHasNotStarted(id)
        nonReentrant
    {
        if(receiver == address(0))
            revert AddressZero();
        assert(asset.transferFrom(msg.sender, address(this), assets));

        _mint(receiver, id, assets, EMPTY);

        emit Deposit(msg.sender, receiver, id, assets);
    }

    /**
        @notice Deposit ETH function
        @param  id  uint256 in UNIX timestamp, representing the end date of the epoch. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1654038000;
        @param receiver  address of the receiver of the shares provided by this function, that represent the ownership of the deposited asset;
     */
    function depositETH(uint256 id, address receiver)
        external
        payable
        marketExists(id)
        epochHasNotStarted(id)
        nonReentrant
    {
        require(msg.value > 0, "ZeroValue");
        if(receiver == address(0))
            revert AddressZero();

        IWETH(address(asset)).deposit{value: msg.value}();
        _mint(receiver, id, msg.value, EMPTY);

        emit Deposit(msg.sender, receiver, id, msg.value);
    }

    /**
    @notice Withdraw entitled deposited assets, checking if a depeg event
    @param  id uint256 in UNIX timestamp, representing the end date of the epoch. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1654038000;
    @param assets   uint256 of how many assets you want to withdraw, this value will be used to calculate how many assets you are entitle to according to the events;
    @param receiver  Address of the receiver of the assets provided by this function, that represent the ownership of the transfered asset;
    @param owner    Address of the owner of these said assets;
    @return shares How many shares the owner is entitled to, according to the conditions;
     */
    function withdraw(
        uint256 id,
        uint256 assets,
        address receiver,
        address owner
    )
        external
        override
        epochHasEnded(id)
        marketExists(id)
        returns (uint256 shares)
    {
        if(receiver == address(0))
            revert AddressZero();

        if(
            msg.sender != owner &&
            isApprovedForAll(owner, msg.sender) == false)
            revert OwnerDidNotAuthorize(msg.sender, owner);

        uint256 entitledShares;
        _burn(owner, id, assets);

        if(epochNull[id] == false) {
            entitledShares = previewWithdraw(id, assets);
            //Taking fee from the premium
            if(entitledShares > assets) {
                uint256 premium = entitledShares - assets;
                uint256 feeValue = calculateWithdrawalFeeValue(premium, id);
                entitledShares = entitledShares - feeValue;
                assert(asset.transfer(treasury, feeValue));
            }
        }
        else{
            entitledShares = assets;
        }
        if (entitledShares > 0) {
            assert(asset.transfer(receiver, entitledShares));
        }

        emit Withdraw(msg.sender, receiver, owner, id, assets, entitledShares);

        return entitledShares;
    }

    /*///////////////////////////////////////////////////////////////
                           ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
        @notice returns total assets for the id of given epoch
        @param  _id uint256 in UNIX timestamp, representing the end date of the epoch. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1654038000;
     */
    function totalAssets(uint256 _id)
        public
        view
        override
        marketExists(_id)
        returns (uint256)
    {
        return totalSupply(_id);
    }

    /**
    @notice Calculates how much ether the %fee is taking from @param amount
    @param amount Amount to withdraw from vault
    @param _epoch Target epoch
    @return feeValue Current fee value
     */
    function calculateWithdrawalFeeValue(uint256 amount, uint256 _epoch)
        public
        view
        returns (uint256 feeValue)
    {
        // 0.5% = multiply by 1000 then divide by 5
        return amount.mulDivUp(epochFee[_epoch],1000);
    }

    /*///////////////////////////////////////////////////////////////
                           Factory FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
    @notice Factory function, changes treasury address
    @param _treasury New treasury address
     */
    function changeTreasury(address _treasury) public onlyFactory {
        if(_treasury == address(0))
            revert AddressZero();
        treasury = _treasury;
    }


    /**
    @notice Factory function, changes controller address
    @param _controller New controller address
     */
    function changeController(address _controller) public onlyFactory{
        if(_controller == address(0))
            revert AddressZero();
        controller = _controller;
    }

    /**
    @notice Function to deploy caramel assets for given epochs, after the creation of this vault
    @param  epochBegin uint256 in UNIX timestamp, representing the begin date of the epoch. Example: Epoch begins in 31/May/2022 at 00h 00min 00sec: 1654038000
    @param  epochEnd uint256 in UNIX timestamp, representing the end date of the epoch and also the ID for the minting functions. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1656630000
    @param _withdrawalFee uint256 of the fee value, multiply your % value by 10, Example: if you want fee of 0.5% , insert 5
     */
    function createAssets(uint256 epochBegin, uint256 epochEnd, uint256 _withdrawalFee)
        public
        onlyFactory
    {
        if(_withdrawalFee > 150)
            revert FeeMoreThan150(_withdrawalFee);

        if(_withdrawalFee == 0)
            revert FeeCannotBe0();

        if(idExists[epochEnd] == true)
            revert MarketEpochExists();

        if(epochBegin >= epochEnd)
            revert EpochEndMustBeAfterBegin();

        idExists[epochEnd] = true;
        idEpochBegin[epochEnd] = epochBegin;
        epochs.push(epochEnd);

        epochFee[epochEnd] = _withdrawalFee;
    }

    /*///////////////////////////////////////////////////////////////
                         CONTROLLER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
    @notice Controller can call this function to trigger the end of the epoch, storing the TVL of that epoch and if a depeg event occurred
    @param  id uint256 in UNIX timestamp, representing the end date of the epoch. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1654038000
     */
    function endEpoch(uint256 id)
        public
        onlyController
        marketExists(id)
    {
        idEpochEnded[id] = true;
        idFinalTVL[id] = totalAssets(id);
    }

    /**
    @notice Function to be called after endEpoch, by the Controller only, this function stores the TVL of the counterparty vault in a mapping to be used for later calculations of the entitled withdraw
    @param  id uint256 in UNIX timestamp, representing the end date of the epoch. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1654038000
    @param claimTVL uint256 representing the TVL the counterparty vault has, storing this value in a mapping
     */
    function setClaimTVL(uint256 id, uint256 claimTVL) public onlyController marketExists(id) {
        idClaimTVL[id] = claimTVL;
    }

    /**
    solhint-disable-next-line max-line-length
    @notice Function to be called after endEpoch and setClaimTVL functions, respecting the calls in order, after storing the TVL of the end of epoch and the TVL amount to claim, this function will allow the transfer of tokens to the counterparty vault
    @param  id uint256 in UNIX timestamp, representing the end date of the epoch. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1654038000
    @param _counterparty Address of the other vault, meaning address of the saltish vault, if this is an caramel vault, and vice-versa
    */
    function sendTokens(uint256 id, address _counterparty)
        public
        onlyController
        marketExists(id)
    {
        assert(asset.transfer(_counterparty, idFinalTVL[id]));
    }

    function setEpochNull(uint256 id) public onlyController marketExists(id) {
        epochNull[id] = true;
    }

    /*///////////////////////////////////////////////////////////////
                         INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
        @notice Shows assets conversion output from withdrawing assets
        @param  id uint256 token id of token
        @param assets Total number of assets
     */
    function previewWithdraw(uint256 id, uint256 assets)
        public
        view
        override
        returns (uint256 entitledAmount)
    {
        // in case the saltish wins aka no depeg event
        // saltish users can withdraw the caramel (that is paid by the caramel buyers) and saltish; withdraw = (saltish + caramel)
        // caramel pay for each caramel seller = ( saltish / tvl before the caramel payouts ) * tvl in caramel pool
        // in case there is a depeg event, the saltish users can only withdraw the caramel
        entitledAmount = assets.mulDivUp(idClaimTVL[id],idFinalTVL[id]);
        // in case the caramel wins aka depegging
        // caramel users pay the caramel to saltish users anyway,
        // caramel guy can withdraw saltish (that is transfered from the saltish pool),
        // withdraw = % tvl that caramel buyer owns
        // otherwise caramel users cannot withdraw any Eth
    }

    /** @notice Lookup total epochs length
      */
    function epochsLength() public view returns (uint256) {
        return epochs.length;
    }

}