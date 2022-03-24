// SPDX-License-Identifier: MIT

/*
 Contract created by Octaplex Smart Contract Solutions
 for more information visit https://octaplex.io/smart-contract-service/

                        Flewup Token Contract

 KEY FEATURES:
    AntiSnipe protection (initial AntiSnipe tax + maximum transaction amount)
    Trading blocked before launch - anti bot protection
    After launch -> trading always possible
    Liquidity injection
    Tax in BNB
    Burnable token (from caller)
    Ownership protection
    Marketing Wallet
    Development Wallet
    Tax exclusion for utility contracts such as marketplaces, staking etc.
    Maximum balance limit per individual wallet

 ********************************************************************************************
                                                    .
                                          :.       .~~^:..
                                         .JJ7!^.   .~~~~~~~:
                                  5J~.   .JJJJJJ~  .~~~~~~~^
                                  GBBG5  .JJJJJJ~  .~~~~~~~:
                                  PGGGP  .JJJJJJ~  .~~~~~~~:
                                  PGGGP  .JJJJJJ~  .~~~~~~~:
                                  PGGGP  .JJJJJJ~  .~~~~~~~:
                                  PGGGP  .JJJJJJ~  .~~~~~~~:
                                  GGBB5  .JJJJJJ~  .~~~~~~~:
                                  GP7:   .JJJJJJ^  .~~~~~~~^
                                  .      .JJ?!:    .~~~~~~^.
                                         .!:       .~~~:.
                                                   .:.


                      .YGBBBBP .GB5    ^BBJ   ~BB5   .GGBBBBP7 PBBGGGBB~
                      #@@7!!!^ :@@@#  7@@@#  :@@@@Y  .@@B^^J@@?^~7@@#~~.
                      J@@&&&#B:.@@&@&P@@@@B  &@G!@@7 .@@B~~Y@@7   @@5
                      .^~~~~@@G.@@J!@@B.&@B #@@&B@@@:.@@&Y#@@5   .@@P
                      P##&&&@&~.&&7     #&5?&&~...B&B:&&7  P&B.  .&&J

           .!J5YY57 ~YYYYYJ~  JY?   JY.?5YJJYY5^~YJYYYJ!.   .JY?    ^?YYYYY?55YJJY5J
           &@&JJJY!?@@5775@@? @@@# .@@!!JY@@&JY:B@@Y?J@@&   &@@@5  ~@@GJJJJ7JJ&@@5J?
          .@@P     G@@   .@@Y @@@@&7@@~   @@G   B@@^..&@@  G@&!@@7 Y@@.       P@@
           @@G     P@@.  .@@5 @@5^@@@@~   @@G   B@@BB@@&^ J@@&P@@@:J@@.       P@@.
           P@@&&#&P^@@&&&&@@^ @@Y .&@@~   &@P   G@&  ?@@!^@@5:^^B@&~&@&&&#&^  5@@.
             .....   ......    .     .     .              .       .  ......    .
         .....   ......    .       .     .. ........ ....   ......    .    ..    .....
      ~&@&##&B .&@&##&@@7.@@Y     G@&   Y@@^#&&@@&&&J&@@@Y #@&###@@J &@@7 .@@!.&@&###&.
      G@@?!!~: 7@@^   @@B.@@5     G@@   5@@.  ^@@?   :@@5 ~@@!   &@& @@@@5.@@!7@@Y~!~:
      .PB##B@@5?@@.   &@B.@@Y     B@@   Y@@.  :@@?   .@@J !@@^   &@& @@BP@&@@7 YB##B&@#
      ~J????@@B^@@G7?J@@P.@@#7???:P@@J?7#@@.  ^@@?  .5@@#^:@@B7??@@B @@G J@@@7.J???7#@@
      ~YYPPP5?. ~Y5PPP5?  ??JJJJY^ 75PPP5J:   .JJ:  .Y??J~ ^Y5PPP5?. ?J~  ^JJ.:YY5PP5J:

 ********************************************************************************************/

pragma solidity ^0.8.9;

interface ERC20 {
    function totalSupply() external view returns (uint _totalSupply);
    function balanceOf(address _owner) external view returns (uint balance);
    function transfer(address _to, uint _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint _value) external returns (bool success);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

interface IPancakeFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

 //   function mint(address to) external returns (uint liquidity);
 //   function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
 //   function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

 contract FlewupToken is ERC20 {
    string public constant symbol = "$Flew";
    string public constant name = "Flewup";
    uint8 public constant decimals = 18;


     //TestNet
    //  address constant routerAddress = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    //MainNet
    address constant routerAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    IPancakeRouter02 private _pancakeRouter = IPancakeRouter02(routerAddress);
    address public _pancakePairAddress;

    address public MainWallet; //address of the wallet that controls the contract
    address public MarketingWallet; //address of the wallet where marketing funds accumilate
    address public DevWallet; //address of the wallet where development funds accumilate

// modifier that allows admin functions to only be called by the Owner (MainWallet)
    modifier onlyMain() {
      require((msg.sender == MainWallet));
      _;
    }

        event TaxUpdated(uint256 MarketingTaxdiv1000, uint256 DevelopmentTaxdiv1000, uint256 LiquidityTaxdiv1000);
        event TokensBurned(uint256 TokensAmount);
        event AntiSnipeEnabled(uint256 duration);
        event Trading_LIVE();

    //10,000,000,000+18 zeros //10000000000
    uint private __totalSupply = 10000000000000000000000000000; //10 billion tokens

    uint256 public MarketingTax = 20; //20/1000 = 2%
    uint256 public DevTax = 20; //20/1000 = 2%
    uint256 public LiquidityTax = 20; //20/1000 //total = 6%
    uint256 public LaunchTime; //set when calling initiateLaunch function

    uint256 public SwapThreshold = __totalSupply / 1000; //0.1% of total supply traded

    bool public TradingStarted; //avoids bots sniping tokens - once trading started is set to true, it cannot be stopped
    bool public AntiSnipeActive = true;
    bool public WorkOnTrade = true;
    uint private AntiSnipeDuration = 20; //20 seconds - increase if launch has to be initialized (trading enabled) before creating the liquidity pool
    uint private AntiSnipeTax = 740; //74% (total 80%)
    uint private AntiSnipeMaxTx = __totalSupply / 500; //0.2% of total supply

    //balances of an address
    mapping (address => uint) private __balanceOf;

    //This is for the approval function to determine how much an address can spend
    mapping (address => mapping (address => uint)) private __allowances;

    //List of wallets/contracts that should be excluded from tax
     mapping (address => bool) public _ExcludedFromTax;
    //List of wallets/contracts that should be excluded from the MaximumTokenBalance
     mapping (address => bool) public _ExcludedFromMaxBalance;

    //The maximum amount of tokens that can be owned by a wallet
    uint256 public MaximumTokenBalance = __totalSupply / 200; //default set to 0.5% of total supply per wallet


    //The creator of the contract has the total supply and no one can create tokens
    //The creator and token contract are excluded from tax
    constructor()
        {
        __balanceOf[msg.sender] = __totalSupply;

        _ExcludedFromTax[address(this)] = true;
        _ExcludedFromTax[msg.sender] = true;

        //set all admin wallets to contract creator as default. Can be changed by contract owner
        MainWallet = msg.sender;
        MarketingWallet = msg.sender;
        DevWallet = msg.sender;

        _pancakePairAddress = IPancakeFactory(_pancakeRouter.factory()).createPair(address(this), _pancakeRouter.WETH());

        //The creator wallet, token contract and main liquidity pair are excluded
        //from the maximum token balance limitation
        _ExcludedFromMaxBalance[msg.sender];
        _ExcludedFromMaxBalance[address(this)];
        _ExcludedFromMaxBalance[_pancakePairAddress];
    }

    //returns the amount of tokens that exist
    function totalSupply() public view override returns (uint _totalSupply) {
        _totalSupply = __totalSupply;
    }


    //returns the balance of a specific address
    function balanceOf(address _addr) public view override returns (uint balance) {
        return __balanceOf[_addr];
    }

    //transfer an amount of tokens to another address.

    function transfer(address _to, uint _value) public override returns (bool success) {

        uint256 taxamount;
        if(!TradingStarted)
         require((_ExcludedFromTax[_to]) || (_ExcludedFromTax[msg.sender]),"Trading is not enabled yet");

        require(_value <= __balanceOf[msg.sender],"Insufficient token balance");
        if((_ExcludedFromTax[_to]) || (_ExcludedFromTax[msg.sender]))
          taxamount = 0;
        else
         {
             if(AntiSnipeActive) //post launch protection
             {
                 updateAntiSnipeStatus(); //check if it can be deactivated yet
                 if(AntiSnipeActive && ((_to == _pancakePairAddress) || (msg.sender == routerAddress) || (msg.sender == _pancakePairAddress))) //if it is still active, add the sniping tax
                    {
                    require(_value <= AntiSnipeMaxTx,"Maximum transaction value exceeded");
                    taxamount = _value * AntiSnipeTax / 1000;
                    }
             }
             taxamount += _value * (MarketingTax+DevTax+LiquidityTax) / 1000;
         }

        uint256 amountout = _value - taxamount;

            __balanceOf[msg.sender] -= _value;

            __balanceOf[_to] += amountout;

            //if the max token balance applies to the wallet, the new receiver wallet must be within the limit
            if(!_ExcludedFromMaxBalance[_to])
             require(__balanceOf[_to] <= MaximumTokenBalance,"Maximum recipient balance exceeded!");

            emit Transfer(msg.sender, _to, amountout);

            if(taxamount > 0) //send tax tokens to contract address
            { __balanceOf[address(this)] += taxamount;
                emit Transfer(msg.sender, address(this), taxamount);
                //if((WorkOnTrade))
                //doWork();
            }

        return true;

    }

    //Taxed transfers are expected to do some work, which includes swapping tax tokens and liquidity injection
    //This function can also be called manually
    //Once the swap threshold is reached, the contract swaps tax tokens for BNB and sets a flag
    //The next time the function is called, the BNB is distributed to marketing and development wallets and liquidity injection and the flag is reset
    bool public workToggleFlag;

    function doWork() public
    {
              if(!workToggleFlag)
            {
            uint256 availableTokens = __balanceOf[address(this)];

            if(availableTokens > SwapThreshold) //time to distribute tax
            {   uint256 TotalTax = MarketingTax+DevTax+LiquidityTax;

                uint256 LiquidityTokens;
                if(LiquidityTax > 0)
                 LiquidityTokens = availableTokens * (LiquidityTax / 2) / TotalTax;
                _swapTokenForBNB(availableTokens - LiquidityTokens);

                workToggleFlag = true;
            }

            }
            else
            {  uint BNBin = address(this).balance;
              if(BNBin > 0)
              { uint256 TotalTax = MarketingTax + DevTax + LiquidityTax;
                //send out bnb portions to external wallets
                SendBNBfromContract(BNBin * MarketingTax / (TotalTax - LiquidityTax / 2), MarketingWallet);
                SendBNBfromContract(BNBin * DevTax / (TotalTax - LiquidityTax / 2), DevWallet);


             //Liquidity Injection with remaining funds
               _addLiquidityFromContract(__balanceOf[address(this)], address(this).balance);
               }
               workToggleFlag = false;
            }

    }

    //Sends liquidity portion from tax to LP contract and sends LP tokens to marketing wallet
       function _addLiquidityFromContract(uint256 tokenamount, uint256 bnbamount) private returns (bool){

         _approveMore(address(this), address(_pancakeRouter), tokenamount);

        _pancakeRouter.addLiquidityETH{value: bnbamount}(
            address(this),
            tokenamount,
            0,
            0,
            MarketingWallet, //Generated LP tokens sent to marketing wallet
            block.timestamp + 20
            );
        return true;


    }

    //Function to check if antisnipe should still be enabled
        function updateAntiSnipeStatus() public
    {   if(LaunchTime + AntiSnipeDuration <= block.timestamp)
        {//disable anti snipe functionality after the timer runs out
            AntiSnipeActive = false;
        }
    }

//function for burning tokens. This decreases the sender balance and total supply with the TokenAmount
//and emits an event that tokens have been burned.
// Do not forget to add the correct amount decimals to the token amount
    function burnTokens(uint256 TokenAmount) public
    {
        require(__balanceOf[msg.sender] >= TokenAmount, "Insufficient token balance");
        __balanceOf[msg.sender] -= TokenAmount;
        __totalSupply -= TokenAmount;

        emit Transfer(msg.sender, address(0), TokenAmount);
        emit TokensBurned(TokenAmount);
    }


    //this allows someone else (a 3rd party) to transfer from my wallet to someone elses wallet
    //If the 3rd party has an allowance of >0
    //and the allowance is >= the value of the transfer
    function transferFrom(address _from, address _to, uint _value) public override returns (bool success) {

     require(__allowances[_from][msg.sender] >= _value,"Insufficient Allowance");
     require(_value <= __balanceOf[_from],"Insufficient token balance");

     __allowances[_from][msg.sender] -= _value;
     __balanceOf[_from] -= _value;

        uint256 taxamount;
        if(!TradingStarted)
         require((_ExcludedFromTax[_to]) || (_ExcludedFromTax[msg.sender]) || (_ExcludedFromTax[_from]),"Trading is not enabled yet");

        if((_ExcludedFromTax[_to]) || (_ExcludedFromTax[msg.sender]) || (_ExcludedFromTax[_from]))
          taxamount = 0;
        else
         {
             if(AntiSnipeActive)
             {
                 updateAntiSnipeStatus(); //check if it can be deactivated yet
                 if(AntiSnipeActive) //if it is still active, add the sniping tax
                 {require(_value <= AntiSnipeMaxTx,"Maximum transaction value exceeded");
                  if((_to == _pancakePairAddress) || (_from == _pancakePairAddress) || (msg.sender == routerAddress)) //buy or sell transaction
                    taxamount = _value * AntiSnipeTax / 1000;
                 }
             }

             taxamount += _value * (MarketingTax+DevTax+LiquidityTax) / 1000;
         }

         uint256 amountout = _value - taxamount;

            __balanceOf[_to] += amountout;

            //if the max token balance applies to the wallet, the new receiver wallet must be within the limit
            if(!_ExcludedFromMaxBalance[_to])
             require(__balanceOf[_to] <= MaximumTokenBalance,"Maximum recipient balance exceeded!");

            emit Transfer(_from, _to, amountout);

            if(taxamount > 0)
            {
                __balanceOf[address(this)] += taxamount;
               // if(WorkOnTrade)
               // doWork(); //moved to approve function
                emit Transfer(_from, address(this), taxamount);
            }
            return true;
    }

    //allows a spender address to spend a specific amount of value
    function approve(address _spender, uint _value) external override returns (bool success) {
        __allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);

        if((WorkOnTrade) && (!_ExcludedFromTax[msg.sender]))
                doWork(); //swap and distribute tax tokens and liquidity
        return true;
    }


    //shows how much a spender has the approval to spend to a specific address
    function allowance(address _owner, address _spender) external override view returns (uint remaining) {
        return __allowances[_owner][_spender];
    }

    //internal function for increasing router approval during tax swaps
         function _approveMore(address _owner, address _spender, uint _value) internal returns (bool success) {
        uint256 old = __allowances[_owner][_spender];
        __allowances[_owner][_spender] += _value;
        emit Approval(_owner, _spender, old + _value);
        return true;
    }

    event Received(address sender, uint amount);
    //function to receive BNB from tax swaps
    receive() external payable {
      emit Received(msg.sender, msg.value);
    }

    //returns the BNB balance of the contract
    function ReservesBNB() public view returns (uint256)
    {
      return address(this).balance;
    }
//returns the Token balance of the contract
    function ReservesToken() public view returns (uint256)
    {
       return __balanceOf[address(this)];
    }

    //trading by taxed wallets only become possible after calling this function.
    //Once trading is started, it cannot be undone
    function initiateLaunch(uint256 antiSnipeDuration_seconds) public onlyMain()
    {
     LaunchTime = block.timestamp;
     AntiSnipeDuration = antiSnipeDuration_seconds;
     if(antiSnipeDuration_seconds > 0)
     {
        AntiSnipeActive = true;
        emit AntiSnipeEnabled(antiSnipeDuration_seconds);
     }
     TradingStarted = true;

     emit Trading_LIVE();
    }

/**Tax Distribution:
Transfer tax is split into three portions, and is equal for buys, sells and transfers between wallets
Excluded wallets are able to transfer tax free, for example future utility contracts

Tax is split into the following portions:
Marketing tax
Development tax
Liquidity injection tax

Once the swap threshold is reached, the tax is converted to bnb, and for the liquidity portion 50% BNB and 50% tokens
*/

  //function to update tax rates and distribution. Enter the desired percentage for each portion.
  //The resolution is 0.1%, for example, to set the Marketing tax to 5%, you would input
  //newMarketingTax = 50, which is equal to 50 / 1000 = 5 / 100 = 5%
   function setTax(uint256 newMarketingTax, uint256 newDevTax, uint256 newLiquidityTax) public onlyMain() {
     require(newMarketingTax + newDevTax + newLiquidityTax <= 200); //maximum limit of 20% total transfer tax
        MarketingTax = newMarketingTax;
        DevTax = newDevTax;
        LiquidityTax = newLiquidityTax;

        emit TaxUpdated(MarketingTax, DevTax, LiquidityTax);
   }

    function ExcludefromTax(address Addr) public onlyMain() {
        _ExcludedFromTax[Addr] = true;
        }

    function UndoExcludefromTax(address Addr) public onlyMain() {
        _ExcludedFromTax[Addr] = false;
        }

    //setting this exclusion cannot be undone after trading has started
    // The maximum balance exclusion cannot be undone as that could affect the tradeability of the token.
    function ExcludefromMaxBalance(address Addr) public onlyMain() {
        _ExcludedFromMaxBalance[Addr] = true;
        }

   // this function is disabled after launch for safety reasons.
   // The maximum balance exclusion cannot be undone as that could affect the tradeability of the token.
    function UndoExcludeMaxBalance(address Addr) public onlyMain() {
        //launch time set => function disabled
        require(!TradingStarted,"Trading already enabled");
        _ExcludedFromMaxBalance[Addr] = false;
        }

    //remember to add 18 decimals when updating the MaxTokenBalance!
    //for holder security, DECREASING the maximum balance is disabled after launch
    //set MaximumTokenBalance to TotalBalance to disable the limitation on all wallets(cannot be undone after launch)
    function updateMaxTokenBalance(uint256 newMaxTokenBalance) public onlyMain(){
        if(TradingStarted)
           require(newMaxTokenBalance >= MaximumTokenBalance, "Maximum balance cannot be decreased after launch");
        MaximumTokenBalance = newMaxTokenBalance;
        }

    function setMainWallet(address Wallet) public onlyMain(){
        MainWallet = Wallet;
        }

    function setMarketingWallet(address Wallet) public onlyMain(){
        MarketingWallet = Wallet;
        }

    function setDevWallet(address Wallet) public onlyMain(){
        DevWallet = Wallet;
        }

    function setWorkonTradeFlag(bool isEnabled) public onlyMain(){
        WorkOnTrade = isEnabled;
        }

    function updateAntiSnipeTax(uint256 newAntiSnipeTax) public onlyMain(){
        AntiSnipeTax = newAntiSnipeTax;
    }

//backup function if the antisniper timer needs to be adjusted
   function updateAntiSnipeDuration(uint256 antiSnipeDuration_seconds) public onlyMain(){
         require(AntiSnipeActive,"AntiSnipe period has already passed");
         AntiSnipeDuration = antiSnipeDuration_seconds;
         updateAntiSnipeStatus(); //sets status to false if timer has ran out with new value.
    }


//sets the number of tax tokens that should accumilate before swapping to BNB
//smaller threshold -> swaps occur more often, but uses more gas
//Dont forget to add the decimals!
    function updateSwapThreshold(uint256 newSwapThreshold) public onlyMain(){
         SwapThreshold = newSwapThreshold;
     }


 //function to safely send BNB from contract
    function SendBNBfromContract(uint256 amountBNB, address receiver) private returns (bool)
    {
     (bool success, ) = receiver.call{ value: amountBNB }(new bytes(0));

     return success;
    }

//function to swap contract tax tokens to BNB for distribution
    function _swapTokenForBNB(uint256 tokenamount) private returns (bool){
     if(tokenamount > 0)
     {

        _approveMore(address(this), address(_pancakeRouter), tokenamount);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _pancakeRouter.WETH();

//function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        _pancakeRouter.swapExactTokensForETH(
            tokenamount,
            0,
            path,
            address(this),
            block.timestamp + 20
            );
        return true;

     }
     return false;

    }

//Tool to fetch the value of the token from the router contract
    function getTokenprice(uint amountBNB) public view returns (uint256)
{
     address[] memory path = new address[](2);
        path[0] = _pancakeRouter.WETH();
        path[1] = address(this);
       uint[] memory amounts =  _pancakeRouter.getAmountsOut(amountBNB, path);

    return amounts[1];
}

//Tool to view the anti-snipe countdown
    function AntiSnipeTimer() public view returns (uint256)
    {
      if(AntiSnipeActive)
        {
            uint256 currentTime = block.timestamp;
            if(LaunchTime + AntiSnipeDuration > currentTime)
            return (LaunchTime + AntiSnipeDuration) - currentTime;
            else return 0;
        }
        else return 0;
    }

}
