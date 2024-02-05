// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Vault} from "./Vault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IController} from "./interfaces/IController.sol";

/// @author MiguelBits

contract TimeLock {

    mapping(bytes32 => bool) public queued;

    address public policy;

    uint256 public constant MIN_DELAY = 7 days;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    error NotOwner(address sender);
    error AlreadyQueuedError(bytes32 txId);
    error TimestampNotInRangeError(uint256 blocktimestamp, uint256 timestamp);
    error NotQueuedError(bytes32 txId);
    error TimestampNotPassedError(uint256 blocktimestamp, uint256 timestamp);
    error TimestampExpiredError(uint256 blocktimestamp, uint256 timestamp);
    error TxFailedError(string func);

    event Queue(
        bytes32 indexed txId,
        address indexed target,
        string func,
        uint index,
        uint data,
        address to,
        address token,
        uint timestamp);

    event Execute(
        bytes32 indexed txId,
        address indexed target,
        string func,
        uint index,
        uint data,
        address to,
        address token,
        uint timestamp);

    event Delete(
        bytes32 indexed txId,
        address indexed target,
        string func,
        uint index,
        uint data,
        address to,
        address token,
        uint timestamp);


    modifier onlyOwner(){
        if(msg.sender != policy)
            revert NotOwner(msg.sender);
        _;
    }

    constructor(address _policy) {
        policy = _policy;
    }

    /**
     * @dev leave params zero if not using them
     * @notice Queue a transaction
     * @param _target The target contract
     * @param _func The function to call
     * @param _index The market index of the vault to call the function on
     * @param _data The data to pass to the function
     * @param _to The address to change the params to
     * @param _token The token to change the params to
     * @param _timestamp The timestamp to execute the transaction
     */
    function queue(
        address _target,
        string calldata _func,
        uint256 _index,
        uint256 _data,
        address _to,
        address _token,
        uint256 _timestamp) external onlyOwner
    {
        //create tx id
        bytes32 txId = getTxId(_target, _func, _index, _data, _to, _token, _timestamp);

        //check tx id unique
        if(queued[txId]){
            revert AlreadyQueuedError(txId);
        }

        //check timestamp
        if(_timestamp < block.timestamp + MIN_DELAY ||
            _timestamp > block.timestamp + MAX_DELAY){
            revert TimestampNotInRangeError(block.timestamp, _timestamp);
        }

        //queue tx
        queued[txId] = true;

        emit Queue(txId, _target,
         _func,
         _index,
         _data,
         _to,
         _token,
         _timestamp);

    }
    /**
     * @dev leave params zero if not using them
     * @notice Execute a Queued a transaction
     * @param _target The target contract
     * @param _func The function to call
     * @param _index The market index of the vault to call the function on
     * @param _data The data to pass to the function
     * @param _to The address to change the params to
     * @param _token The token to change the params to
     * @param _timestamp The timestamp after which to execute the transaction
     */
    function execute(
        address _target,
        string calldata _func,
        uint256 _index,
        uint256 _data,
        address _to,
        address _token,
        uint256 _timestamp) external onlyOwner
    {
        bytes32 txId = getTxId(_target, _func, _index, _data, _to, _token, _timestamp);

        //check tx id queued
        if(!queued[txId]){
            revert NotQueuedError(txId);
        }

        //check block.timestamp > timestamp
        if(block.timestamp < _timestamp){
            revert TimestampNotPassedError(block.timestamp, _timestamp);
        }
        if(block.timestamp > _timestamp + GRACE_PERIOD){
            revert TimestampExpiredError(block.timestamp, _timestamp + GRACE_PERIOD);
        }

        //delete tx from queue
        queued[txId] = false;

        //execute tx
        if(compareStringsbyBytes(_func, "changeTreasury")){
            VaultFactory(_target).changeTreasury(_to, _index);
        }

        else if(compareStringsbyBytes(_func, "changeController")){
            VaultFactory(_target).changeController(_index, _to);
        }

        else if(compareStringsbyBytes(_func, "changeOracle")){
            VaultFactory(_target).changeOracle(_token, _to);
        }

        else{
            revert TxFailedError(_func);
        }

        emit Execute(
        txId,
        _target,
        _func,
        _index,
        _data,
        _to,
        _token,
        _timestamp);

    }

    function cancel(
        address _target,
        string calldata _func,
        uint256 _index,
        uint256 _data,
        address _to,
        address _token,
        uint256 _timestamp) external onlyOwner
    {
        bytes32 txId = getTxId(_target, _func, _index, _data, _to, _token, _timestamp);

        //check tx id queued
        if(!queued[txId]){
            revert NotQueuedError(txId);
        }

        //delete tx from queue
        queued[txId] = false;

        emit Delete(
        txId,
        _target,
        _func,
        _index,
        _data,
        _to,
        _token,
        _timestamp);
    }

    function getTxId(address _target,
        string calldata _func,
        uint _index,
        uint _data,
        address _to,
        address _token,
        uint _timestamp
    ) public pure returns (bytes32 txId){
        return keccak256(abi.encode(
            _target,
            _func,
            _index,
            _data,
            _to,
            _token,
            _timestamp
        ));
    }

    function compareStringsbyBytes(string memory s1, string memory s2) public pure returns(bool){
        return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }

    function changeOwner(address _newOwner) external onlyOwner {
        policy = _newOwner;
    }
}

contract VaultFactory is Ownable {

    address public immutable WETH;
    // solhint-enable var-name-mixedcase
    address public treasury;
    address public controller;
    uint256 public marketIndex;

    TimeLock public timelocker;

    struct MarketVault{
        uint256 index;
        uint256 epochBegin;
        uint256 epochEnd;
        Vault caramel;
        Vault saltish;
        uint256 withdrawalFee;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyTimeLocker(){
        if(msg.sender != address(timelocker))
            revert NotTimeLocker();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error MarketDoesNotExist(uint256 marketIndex);
    error AddressZero();
    error AddressNotController();
    error AddressFactoryNotInController();
    error ControllerNotSet();
    error NotTimeLocker();
    error ControllerAlreadySet();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /** @notice Market is created when event is emitted
      * @param mIndex Current market index
      * @param caramel Caramel vault address
      * @param saltish Saltish vault address
      * @param token Token address
      * @param name Market name
      */
    event MarketCreated(
        uint256 indexed mIndex,
        address caramel,
        address saltish,
        address token,
        string name,
        int256 strikePrice
    );

    /** @notice Epoch is created when event is emitted
      * @param marketEpochId Current market epoch id
      * @param mIndex Current market index
      * @param startEpoch Epoch start time
      * @param endEpoch Epoch end time
      * @param caramel Caramel vault address
      * @param saltish Saltish vault address
      * @param token Token address
      * @param name Market name
      * @param strikePrice Vault strike price
      */
    event EpochCreated(
        bytes32 indexed marketEpochId,
        uint256 indexed mIndex,
        uint256 startEpoch,
        uint256 endEpoch,
        address caramel,
        address saltish,
        address token,
        string name,
        int256 strikePrice,
        uint256 withdrawalFee
    );

    /** @notice Controller is set when event is emitted
      * @param newController Address for new controller
      */
    event controllerSet(address indexed newController);

    /** @notice Treasury is changed when event is emitted
      * @param _treasury Treasury address
      * @param _marketIndex Target market index
      */
    event changedTreasury(address _treasury, uint256 indexed _marketIndex);

    /** @notice Vault fee is changed when event is emitted
      * @param _marketIndex Target market index
      * @param _feeRate Target fee rate
      */
    event changedVaultFee(uint256 indexed _marketIndex, uint256 _feeRate);

    /** @notice Controller is changed when event is emitted
      * @param _marketIndex Target market index
      * @param controller Target controller address
      */
    event changedController(
        uint256 indexed _marketIndex,
        address indexed controller
    );
    event changedOracle(address indexed _token, address _oracle);

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address[]) public indexVaults; //[0] caramel and [1] saltish vault
    mapping(uint256 => uint256[]) public indexEpochs; //all epochs in the market
    mapping(address => address) public tokenToOracle; //token address to respective oracle smart contract address

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /** @notice Contract constructor
      * @param _treasury Treasury address
      * @param _weth Wrapped Ether token address
      */
    constructor(
        address _treasury,
        address _weth,
        address _policy
    ) {
        timelocker = new TimeLock(_policy);

        if(_weth == address(0))
            revert AddressZero();

        if(_treasury == address(0))
            revert AddressZero();

        WETH = _weth;
        marketIndex = 0;
        treasury = _treasury;
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
    @notice Function to create two new vaults, caramel and saltish, with the respective params, and storing the oracle for the token provided
    @param _withdrawalFee uint256 of the fee value, multiply your % value by 10, Example: if you want fee of 0.5% , insert 5
    @param _token Address of the oracle to lookup the price in chainlink oracles
    @param _strikePrice uint256 representing the price to trigger the depeg event, needs to be 18 decimals
    @param  epochBegin uint256 in UNIX timestamp, representing the begin date of the epoch. Example: Epoch begins in 31/May/2022 at 00h 00min 00sec: 1654038000
    @param  epochEnd uint256 in UNIX timestamp, representing the end date of the epoch. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1656630000
    @param  _oracle Address representing the smart contract to lookup the price of the given _token param
    @return insr    Address of the deployed caramel vault
    @return rsk     Address of the deployed saltish vault
     */
    function createNewMarket(
        uint256 _withdrawalFee,
        address _token,
        int256 _strikePrice,
        uint256 epochBegin,
        uint256 epochEnd,
        address _oracle,
        string memory _name
    ) public onlyOwner returns (address insr, address rsk) {

        if(controller == address(0))
            revert ControllerNotSet();

        if(
            IController(controller).getVaultFactory() != address(this)
            )
            revert AddressFactoryNotInController();

        marketIndex += 1;

        //sugarUSDC_99*SALTISH or sugarUSDC_99*CARAMEL

        Vault caramel = new Vault(
            WETH,
            string(abi.encodePacked(_name,"CARAMEL")),
            "cSugar",
            treasury,
            _token,
            _strikePrice,
            controller
        );

        Vault saltish = new Vault(
            WETH,
            string(abi.encodePacked(_name,"SALTISH")),
            "sSugar",
            treasury,
            _token,
            _strikePrice,
            controller
        );

        indexVaults[marketIndex] = [address(caramel), address(saltish)];

        if (tokenToOracle[_token] == address(0)) {
            tokenToOracle[_token] = _oracle;
        }

        emit MarketCreated(
            marketIndex,
            address(caramel),
            address(saltish),
            _token,
            _name,
            _strikePrice
        );

        MarketVault memory marketVault = MarketVault(marketIndex, epochBegin, epochEnd, caramel, saltish, _withdrawalFee);

        _createEpoch(marketVault);

        return (address(caramel), address(saltish));
    }

    /**
    @notice Function to deploy caramel assets for given epochs, after the creation of this vault, where the Index is the date of the end of epoch
    @param  index uint256 of the market index to create more assets in
    @param  epochBegin uint256 in UNIX timestamp, representing the begin date of the epoch. Example: Epoch begins in 31/May/2022 at 00h 00min 00sec: 1654038000
    @param  epochEnd uint256 in UNIX timestamp, representing the end date of the epoch and also the ID for the minting functions. Example: Epoch ends in 30th June 2022 at 00h 00min 00sec: 1656630000
    @param _withdrawalFee uint256 of the fee value, multiply your % value by 10, Example: if you want fee of 0.5% , insert 5
     */
    function deployMoreAssets(
        uint256 index,
        uint256 epochBegin,
        uint256 epochEnd,
        uint256 _withdrawalFee
    ) public onlyOwner {
        if(controller == address(0))
            revert ControllerNotSet();

        if (index > marketIndex) {
            revert MarketDoesNotExist(index);
        }
        address caramel = indexVaults[index][0];
        address saltish = indexVaults[index][1];

        MarketVault memory marketVault = MarketVault(index, epochBegin, epochEnd, Vault(caramel), Vault(saltish), _withdrawalFee);

        _createEpoch(marketVault);
    }

    function _createEpoch(
        MarketVault memory _marketVault
    ) internal {

        _marketVault.caramel.createAssets(_marketVault.epochBegin, _marketVault.epochEnd, _marketVault.withdrawalFee);
        _marketVault.saltish.createAssets(_marketVault.epochBegin, _marketVault.epochEnd, _marketVault.withdrawalFee);

        indexEpochs[_marketVault.index].push(_marketVault.epochEnd);

        emit EpochCreated(
            keccak256(abi.encodePacked(_marketVault.index, _marketVault.epochBegin, _marketVault.epochEnd)),
            _marketVault.index,
            _marketVault.epochBegin,
            _marketVault.epochEnd,
            address(_marketVault.caramel),
            address(_marketVault.saltish),
            _marketVault.caramel.tokenInsured(),
            _marketVault.caramel.name(),
            _marketVault.caramel.strikePrice(),
            _marketVault.withdrawalFee
        );
    }

    /**
    @notice Admin function, sets the controller address one time use function only
    @param  _controller Address of the controller smart contract
     */
    function setController(address _controller) public onlyOwner {
        if(controller == address(0)){
            if(_controller == address(0))
                revert AddressZero();
            controller = _controller;

            emit controllerSet(_controller);
        }
        else{
            revert ControllerAlreadySet();
        }
    }

    /**
    @notice Admin function, changes the assigned treasury address
    @param _treasury Treasury address
    @param  _marketIndex Target market index
     */
    function changeTreasury(address _treasury, uint256 _marketIndex)
        public
        onlyTimeLocker
    {
        if(_treasury == address(0))
            revert AddressZero();

        treasury = _treasury;
        address[] memory vaults = indexVaults[_marketIndex];
        Vault insr = Vault(vaults[0]);
        Vault saltish = Vault(vaults[1]);
        insr.changeTreasury(_treasury);
        saltish.changeTreasury(_treasury);

        emit changedTreasury(_treasury, _marketIndex);
    }


    /**
    @notice Admin function, changes controller address
    @param _marketIndex Target market index
    @param  _controller Address of the controller smart contract
     */
    function changeController(uint256 _marketIndex, address _controller)
        public
        onlyTimeLocker
    {
        if(_controller == address(0))
            revert AddressZero();

        address[] memory vaults = indexVaults[_marketIndex];
        Vault insr = Vault(vaults[0]);
        Vault saltish = Vault(vaults[1]);
        insr.changeController(_controller);
        saltish.changeController(_controller);

        emit changedController(_marketIndex, _controller);
    }

    /**
    @notice Admin function, changes oracle address for a given token
    @param _token Target token address
    @param  _oracle Oracle address
     */
    function changeOracle(address _token, address _oracle) public onlyTimeLocker {
        if(_oracle == address(0))
            revert AddressZero();
        if(_token == address(0))
            revert AddressZero();

        tokenToOracle[_token] = _oracle;
        emit changedOracle(_token, _oracle);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /**
    @notice Function the retrieve the addresses of the caramel and saltish vaults, in an array, in the respective order
    @param index uint256 of the market index which to the vaults are associated to
    @return vaults Address array of two vaults addresses, [0] being the caramel vault, [1] being the saltish vault
     */
    function getVaults(uint256 index)
        public
        view
        returns (address[] memory vaults)
    {
        return indexVaults[index];
    }
}