// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
/*\
Created by SolidityX for Decision Game
Telegram: @solidityX
\*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/*\
Uniswap router interface so that the contract can swap tokens;
\*/
interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

/*\
used to check if the user has any of the tokens
\*/
interface IERC1155 {
    function balanceOf(address account, uint id) external returns(uint);   
}

/*\
used to check if the user has any of the tokens
\*/
interface IERC721 {
    function balanceOf(address account) external view returns (uint256);
}

/*\
used to deposit funds into the treasury
\*/
interface IVault {
    function deposit(address _token, uint _amount) external returns(bool);
}

/*\
link swap contract to convert erc20 link into erc677 link
\*/
interface ILinkSwap {
    function swap(uint256 amount, address source, address target) external;
}

/*\
used to deposit erc677 link into the chainlink automation
\*/
interface automation {
    function addFunds(uint256 id, uint96 amount) external;
}


contract Battle {

    using SafeMath for uint;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*\
    saves all values of each gamme
    \*/
    struct game {
        address player1;
        address player2;
        uint256 stakes;
        address winner;
        uint startedAt;
        uint feePaid;
    }

    /*\
    saves stats of each wallet
    \*/
    struct player {
        uint[] gamesPlayed;
        uint[] gamesWon;
        uint[] gamesLost;
        uint[] gamesDrawn;
    }


    address private owner; // owner of contract
    address private dev; // address of dev 
    address private LPstaking; // address of LP staking contract
    address constant private weth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // weth address
    address constant private dead = 0x000000000000000000000000000000000000dEaD; // dead address

    EnumerableSet.AddressSet private operators; // list of all operators
    IUniswapV2Router private router; // router address of dex
    automation private registry; // registry of chainlink automation
    IVault private team; // address of treasury
    IERC20 constant private mainToken = IERC20(0x8865BC57c58Be23137ACE9ED1Ae1A05fE5c8B209); // main tkens address
    IERC721 constant private erc721 = IERC721(0x564e6588DAfA2F79c5805e07860CB869AEdb33d9); // nft tokens contract
    IERC1155 constant private erc1155 = IERC1155(0x46d0DD5aafeb3cd3Ec75907312e911ea806bDFA7); // address of erc155 tken
    ILinkSwap constant private linkSwap = ILinkSwap(0xAA1DC356dc4B18f30C347798FD5379F3D77ABC5b); // to convert link1 to link2
    IERC20 constant private link = IERC20(0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39); // chainlink's link token
    IERC20 constant private link2 = IERC20(0xb0897686c545045aFc77CF20eC7A532E3120E0F1); //chainlink's link token for automation deposit
    
    mapping(address => uint) private inGame; // mapping to check which game the player is currently on
    mapping(uint => game) private Gamelist; // mapping from gameId to game
    mapping(address => player) private stats; // mapping from player to playerStats
    

    uint private id; // id of chainlink automation
    uint private currentGame = 1; // current  game  id
    uint private feePP = 5e16; // matic fee per player
    uint private fee; // current fee
    uint private mFee; // current matic fee
    uint private minFeeForExecution = 100e18; // minimum fee to execute proccessing
    uint constant public burnFee = 6; // token burn fee given in percent
    uint constant public teamFee = 1; // treasury fee given in percent
    uint constant public LPStakingFee = 3; // lp staking reward fee given in percent
    uint constant public tFee = 10; // total fee given in percent

    /*\
    sets all important variable and approves tokens accordingly at deployment
    \*/
    constructor(address _operator, address _staking, address _team, address _router, address _registry, uint _id){
        owner = msg.sender;
        dev = msg.sender;
        operators.add(_operator);
        LPstaking = _staking;
        team = IVault(_team);
        router = IUniswapV2Router(_router);
        registry = automation(_registry);
        id = _id;
        mainToken.approve(address(team), 2**256 - 1);
        link2.approve(address(registry), 2**256-1); 
        link.approve(address(linkSwap), 2**256-1);
    }

    /*\
    functions with this modifier can only be called by the owner or dev
    \*/
    modifier onlyOwner() {
        require(owner == msg.sender, "!owner");
        _;
    }

    /*\
    functions with this modifier can only be called by the dev or owner
    \*/
    modifier onlyDev() {
        require(msg.sender == dev || msg.sender == owner, "!dev");
        _;
    }

    /*\
    functions with this modifier can only be called by the operators
    \*/
    modifier onlyOperator() {
        require(operators.contains(msg.sender), "!operator");
        _;
    }

    event newGame(uint indexed id, address indexed creator, uint indexed bet); // event for newGame
    event joinedGame(uint indexed id, address indexed player, uint indexed bet); // event for joining game
    event endedGame(uint indexed id, address indexed winner, uint indexed bet); // event for ending games
    event gameCanceled(uint indexed id, address indexed creator); // event for canceled games
    event FeeChanged(uint indexed oldFee, uint indexed newFee); // event for fee changes
    event idChanged(uint indexed oldId, uint indexed newId); // event for chainlink automation id changes
    event treasuryChanged(address indexed oldTreasury, address indexed newTreasury); // event for treasury change
    event registryChanged(address indexed oldRegisty, address indexed newRegistry); // event for chainlink registry change
    event routerChanged(address indexed oldRouter, address indexed newRouter); // event for router change
    event stakingChanged(address indexed oldStaking, address indexed newStaking); // event for staking contract change
    event minFeeForExecutionChanged(uint indexed oldMin, uint indexed newMin); // event for minFeeForExecution change
    event ownershipTransfered(address indexed oldOwner, address indexed newOwner); // event for owner change
    event devTransfered(address indexed oldDev, address indexed newDev); // event for dev change

/*//////////////////////////////////////////////‾‾‾‾‾‾‾‾‾‾\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*\
///////////////////////////////////////////////executeables\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
\*\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\____________/////////////////////////////////////////////*/


    /*\
    sets id of chainlink automation
    \*/
    function setId(uint _id) public onlyDev {
        uint oldId = id;
        id = _id;
        emit idChanged(oldId, _id);
    }

    /*\
    set matic fee per player
    \*/
    function setFeePP(uint _fee) public onlyOwner {
        uint oldFee = feePP;
        feePP = _fee;
        emit FeeChanged(oldFee, _fee);
    }

    /*\
    sets registry of chainlink automation
    \*/
    function setRegistry(address _registry) public onlyDev {
        require(_registry != address(0x0), "registry cannot be 0x0!");
        address oldRegistry = address(registry);
        registry = automation(_registry);
        emit registryChanged(oldRegistry, address(registry));
    }

    /*\
    sets router address
    \*/
    function setRouter(address _router) public onlyOwner {
        address oldRouter = address(router);
        router = IUniswapV2Router(_router);
        emit routerChanged(oldRouter, _router);
    }

    /*\
    transfers owner
    \*/
    function setOwner(address _add) public onlyOwner{
        address oldOwner = owner;
        owner = _add;
        emit ownershipTransfered(oldOwner, _add);
    }

    /*\
    transfers dev
    \*/
    function transferDev(address _add) public onlyDev {
        address oldDev = dev;
        dev = _add;
        emit devTransfered(oldDev, _add);
    }

    /*\
    renounce owner
    \*/
    function renounceOwner() public onlyOwner{
        address oldOwner = owner;
        owner = address(0x0);
        emit ownershipTransfered(oldOwner, address(0x0));
    }

    /*\
    set team address (treasury)
    \*/
    function setTeam(address _add) public onlyOwner {
        require(_add != address(0x0), "treasury can't be 0x0!");
        address oldTeam = address(team);
        team = IVault(_add);
        emit treasuryChanged(oldTeam, _add);
    }

    /*\
    set staking contract
    \*/
    function setStaking(address _add) public onlyOwner {
        require(_add != address(0x0), "staking can't be 0x0!");
        address oldLPStaking = LPstaking;
        LPstaking = _add;
        emit stakingChanged(oldLPStaking, _add);
    }

    /*\
    sets the minimum amount of tokens where the fee distribution is triggered
    \*/
    function setMinFeeForExecution(uint _min) public onlyDev {
        uint oldMinFeeForExecution = minFeeForExecution;
        minFeeForExecution = _min;
        emit minFeeForExecutionChanged(oldMinFeeForExecution, _min);
    }

    /*\
    toggles operator
    \*/
    function setOperator(address _add) public onlyOwner{
        require(_add != address(0x0), "operator can't be 0x0!");
        if (operators.contains(_add))
            operators.remove(_add);
        else
            operators.add(_add);
    }

    /*\
    create a new game
    \*/
    function createGame(uint256 _bet) public payable returns(uint256 _id, uint256 bet, bool started) {
        require(inGame[msg.sender] == 0, "already joined a game atm!");
        require(msg.value == feePP, "please provide the required fee!"); 
        require(_bet >= 10e18, "Bet must be higher than 10!");
        require(_bet <= 10000e18, "bet too big!");
        require(mainToken.transferFrom(msg.sender, address(this), _bet), "bet transfer failed!");
        
        if(_bet >= 100e18 && _bet < 1000e18) {
            require(erc1155.balanceOf(msg.sender, 1) > 0 ||
                    erc1155.balanceOf(msg.sender, 2) > 0 ||
                    erc1155.balanceOf(msg.sender, 3) > 0 ||
                    erc1155.balanceOf(msg.sender, 4) > 0 ||
                    erc1155.balanceOf(msg.sender, 5) > 0, "Please purchse coin! (erc1155)");
        }
        if(_bet >= 1000e18)
            require(erc721.balanceOf(msg.sender) > 0, "please purchase a nft. (erc721)");
        
        inGame[msg.sender] = currentGame;
        game memory Game = game(msg.sender, address(0x0), _bet, address(0x0), block.timestamp, feePP);
        stats[msg.sender].gamesPlayed.push(currentGame);
        Gamelist[currentGame] = Game;
        currentGame++;
        
        emit newGame(currentGame-1, msg.sender, _bet);
        
        return (currentGame, _bet, false);
    }

    /*\
    join a game
    \*/
    function joinGame(uint _id) public payable returns(bool){
        require(msg.value == Gamelist[_id].feePaid, "please provide the required fee!"); 
        require(inGame[msg.sender] == 0, "already joined a game atm!");
        require(mainToken.transferFrom(msg.sender, address(this), Gamelist[_id].stakes), "payment failed!");
        require(Gamelist[_id].winner == address(0x0), "game was shut down!");
        require(Gamelist[_id].player1 != address(0x0), "invalid id!");
        require(Gamelist[_id].player2 == address(0x0), "game full!");
        
        inGame[msg.sender] = _id;
        Gamelist[_id].player2 = msg.sender;
        stats[msg.sender].gamesPlayed.push(_id);
        
        emit joinedGame(_id, msg.sender, Gamelist[_id].stakes);
        
        return true;
    }

    /*\
    cancels game if no other player joins
    \*/
    function cancel(uint _id) public returns(bool){
        require(Gamelist[_id].player2 == address(0x0), "opponent already joined!");
        require(Gamelist[_id].player1 == msg.sender || operators.contains(msg.sender), "not game creator or operator!");
        require(mainToken.transfer(Gamelist[_id].player1, Gamelist[_id].stakes), "refund transfer failed!");
        
        inGame[Gamelist[_id].player1] = 0;
        Gamelist[_id].player2 = Gamelist[_id].player1;
        Gamelist[_id].winner = Gamelist[_id].player1;
        
        payable(Gamelist[_id].player1).transfer(Gamelist[_id].feePaid);
        
        emit gameCanceled(_id, Gamelist[_id].player1);
        
        return true;
    }

    /*\
    operator ends game and sets winner
    \*/
    function endGame(uint256 _id, address winner) public onlyOperator returns(bool){
        require(Gamelist[_id].winner == address(0x0), "winner already set!");
        require(Gamelist[_id].player2 != address(0x0),  "game not full!");
        require(winner == address(0x0) || winner == Gamelist[_id].player1 || winner == Gamelist[_id].player2, "winner not player or draw");
        
        inGame[Gamelist[_id].player1] = 0;
        inGame[Gamelist[_id].player2] = 0;
        
        Gamelist[_id].winner = winner == address(0x0) ? msg.sender : winner;
        
        payable(msg.sender).transfer(feePP);
        
        _distributeFee();

        emit endedGame(_id, winner, Gamelist[_id].stakes);

        if(winner == address(0x0)) {
            require(mainToken.transfer(Gamelist[_id].player1, Gamelist[_id].stakes), "transfer failed, 1!");
            require(mainToken.transfer(Gamelist[_id].player2, Gamelist[_id].stakes), "transfer failed, 2!");
            stats[Gamelist[_id].player1].gamesDrawn.push(_id);
            stats[Gamelist[_id].player2].gamesDrawn.push(_id);
            return true;
        }
        
        mFee = mFee.add(feePP);
        uint _fee = (Gamelist[_id].stakes.mul(2)).mul(tFee).div(100);
        fee = fee.add(_fee);
        uint win = (Gamelist[_id].stakes.mul(2)).sub(_fee);
        require(mainToken.transfer(winner, win), "transfer failed, winner!");

        address loser = winner == Gamelist[_id].player1 ? Gamelist[_id].player2 : Gamelist[_id].player1;
        stats[winner].gamesWon.push(_id);
        stats[loser].gamesLost.push(_id);

        return true;
    }

    /*\
    distributes the fee in it exceeds the minFeeForExecution
    \*/
    function _distributeFee() private {
        if(fee >= minFeeForExecution) {
            uint _burnFee = fee.mul(burnFee).div(tFee);
            uint _teamFee = fee.mul(teamFee).div(tFee);
            uint _LPStakingFee = fee.mul(LPStakingFee).div(tFee);
            mainToken.transfer(dead, _burnFee);
            require(team.deposit(address(mainToken), _teamFee), "transfer failed, team vault!");
            require(mainToken.transfer(LPstaking, _LPStakingFee), "transfer failed, LP Staking!");
            require(_fundAutomation(), "automation funding failed!");
            fee = 0;
            mFee = 0;
        }
    }


    /*\
    funds chainlink automation with link
    \*/
    function _fundAutomation() private returns(bool) {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(link);
        
        router.swapExactETHForTokens {value: mFee}(
            0,
            path,
            address(this),
            block.timestamp
        );
        
        linkSwap.swap(link.balanceOf(address(this)), address(link), address(link2));
        registry.addFunds(id, uint96(link2.balanceOf(address(this))));
        
        return true;
    }

    /*\
    allows contract to receive ETH
    \*/
    receive() external payable {}


/*//////////////////////////////////////////////‾‾‾‾‾‾‾‾‾‾‾\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*\
///////////////////////////////////////////////viewable/misc\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
\*\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_____________/////////////////////////////////////////////*/


    /*\
    returns the owner's address
    \*/
    function getOwner() external view returns(address) {
        return owner;
    }

    /*\
    returns the dev's address
    \*/
    function getDev() external view returns(address) {
        return dev;
    }

    /*\
    returns latest game id
    \*/
    function latestGame() external view returns(uint) {
        return currentGame;
    }

    /*\
    return the current feePP
    \*/
    function getFeePP() external view returns(uint) {
        return feePP;
    }

    /*\
    gets the fee paid or that needs to be paid to join the game
    \*/
    function getFeeFor(uint _id) external view returns(uint) {
        return Gamelist[_id].feePaid;
    }

    /*\
    returns total games won of address
    \*/
    function getTotalWonOf(address _add) public view returns(uint) {
        return stats[_add].gamesWon.length;
    }

    /*\
    returns total lost games of address
    \*/
    function getTotalLostOf(address _add) public view returns(uint) {
        return stats[_add].gamesLost.length;
    }

    /*\
    returns total played games of address
    \*/
    function getTotalPlayedOf(address _add) public view returns(uint) {
        return stats[_add].gamesPlayed.length;
    }

    /*\
    return what address is currently playing on
    \*/
    function playingOn(address _add) external view returns(uint) {
        return inGame[_add];
    }

    /*\
    returns all ids of won games of address
    \*/
    function getAllWonOf(address _add) external view returns(uint[] memory) {
        return stats[_add].gamesWon;
    }

    /*\
    returns all ids of games played of address
    \*/
    function getAllPlayedOf(address _add) external view returns(uint[] memory) {
        return stats[_add].gamesPlayed;
    }

    /*\
    returns all ids of lost games of address
    \*/
    function getAllLostOf(address _add) external view returns(uint[] memory) {
        return stats[_add].gamesLost;
    }

    /*\
    returns all ids of draw games of address 
    \*/
    function getAllDrawnOf(address _add) external view returns(uint[] memory) {
        return stats[_add].gamesDrawn;
    }

    /*\
    returns total games drawn of address
    \*/
    function getTotalGamesDrawnOf(address _add) public view returns(uint) {
        return getTotalPlayedOf(_add) - (getTotalWonOf(_add) + getTotalLostOf(_add));
    }

    /*\
    returns W/L rate of player
    \*/
    function getWLOf(address _add) external view returns(uint)  {
        return getTotalWonOf(_add) * 1e18 / getTotalLostOf(_add);
    }  

    /*\
    returns win percentage of player
    \*/
    function getWinPercentageOf(address _add) external view returns(uint) {
        return 100e18 / getTotalPlayedOf(_add) * getTotalWonOf(_add);
    }

    /*\
    returns loose percentage of player
    \*/
    function getLoosePercentageOf(address _add) external view returns(uint) {
        return 100e18 / getTotalPlayedOf(_add) * getTotalLostOf(_add);
    }

    /*\
    returns draw percentage of player
    \*/
    function getDrawPercentageOf(address _add) external view returns(uint) {
        return 100e18 / getTotalPlayedOf(_add) * getTotalGamesDrawnOf(_add);
    }
    
    /*\
    returns information of game id
    \*/
    function getGame(uint _id) external view returns(uint, uint, address, address, address, uint) {
        return (getState(_id), Gamelist[_id].stakes, Gamelist[_id].player1, Gamelist[_id].player2, Gamelist[_id].winner, Gamelist[_id].feePaid);
    }

    /*\
    returns current state of game id
    \*/
    function getState(uint _id) public view returns(uint) {
        uint state = 0;
        if(Gamelist[_id].winner != address(0x0))
            state = 3;
        else if(Gamelist[_id].player1 != address(0x0) && Gamelist[_id].player2 == address(0x0))
            state = 1;
        else if(Gamelist[_id].player1 != address(0x0) && Gamelist[_id].player2 != address(0x0))
            state = 2;
        return state;
    }

    /*\
    get a list of all operators
    \*/
    function getOperators() external view returns(address[] memory) {
        address[] memory ops = new address[](operators.length());
        for(uint i; i < ops.length; i++) {
            ops[i] = operators.at(i);
        }
        return ops;
    } 

    /*\
    returns all current active games
    \*/
    function getAllActive(uint _start) external view returns(uint[] memory, uint[] memory, uint[] memory, uint) {
        uint count = 0;
        for(uint i = _start; i < currentGame; i++) {
            if(Gamelist[i].winner == address(0x0))
                count++;
        }
        uint[] memory _id = new uint[](count);
        uint[] memory _times = new uint[](count);
        uint[] memory _state = new uint[](count);
        count = 0;
        for(uint i = _start; i < currentGame; i++) {
            if(Gamelist[i].winner == address(0x0)) {
                _id[count] = i;
                _times[count] = Gamelist[i].startedAt;
                _state[count] = getState(i);
                count++;
            }
        }
        return (_id, _times, _state, block.timestamp);
    }
}