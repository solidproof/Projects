//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.6;
pragma abicoder v2;

import "./I_Toiletpaper_Matic.sol";

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";


/*

██████╗░██╗░░░██╗████████╗████████╗░█████╗░██╗░░██╗░█████╗░██╗███╗░░██╗
██╔══██╗██║░░░██║╚══██╔══╝╚══██╔══╝██╔══██╗██║░░██║██╔══██╗██║████╗░██║
██████╦╝██║░░░██║░░░██║░░░░░░██║░░░██║░░╚═╝███████║███████║██║██╔██╗██║
██╔══██╗██║░░░██║░░░██║░░░░░░██║░░░██║░░██╗██╔══██║██╔══██║██║██║╚████║
██████╦╝╚██████╔╝░░░██║░░░░░░██║░░░╚█████╔╝██║░░██║██║░░██║██║██║░╚███║
╚═════╝░░╚═════╝░░░░╚═╝░░░░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝

https://buttchain.xyz

© Copyright ButtChain 2024 – All Rights Reserved

*/

contract Butcoin is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    using SafeMathUpgradeable for uint256;

    // ---- Events ----
    event mint_event(
        address indexed recipient_address,
        address indexed referral_address,
        string metadata
    );

    event buy_event(
        uint256 amount_in,
        address indexed recipient_address,
        address indexed referral_address
    );

    event sell_event(
        uint256 amount_in,
        address indexed recipient_address,
        address indexed referral_address
    );

    event seppuku_event(
        address indexed samurai_address
    );


    // ---- Structs ----
    struct Purchase_Data {
        address recipient_address;
        address referral_address;
        uint256 butcoin_amount;
        uint256 referral_amount;
        string metadata;
        uint256 timestamp;
    }

    // ---- Constants ----
    address public constant Deposit_Address = 0x899aBE2FE7390334727B59A1c1C2DA467Fa6D67B;
    address public constant Team_Address = 0xba76845A01BB70bB9F9356832372798b41D8CdcE;
    address public constant Extra_Liquidity_Address = 0x899aBE2FE7390334727B59A1c1C2DA467Fa6D67B;
    address public constant Airdrop_Address = 0x899aBE2FE7390334727B59A1c1C2DA467Fa6D67B;

    uint256 public constant Presale_Butcoins_Per_Matic = 10;
    uint256 public constant Presale_Cuttoff_Date = 1735660799;
    uint256 public constant Presale_Cap = 250 * 10**6 * 10**18;

    uint256 public constant Presale_Min_Matic_For_Mint = 0;
    uint256 public constant Presale_Liquidity_Ratio = 200; // div 1000
    uint256 public constant Presale_Team_Tokens_Ratio = 50; // div 1000
    uint256 public constant Presale_Extra_Liquidity_Tokens_Ratio = 50; // div 1000
    uint256 public constant Presale_Airdrop_Tokens_Ratio = 1; // div 1000
    uint256 public constant Presale_Referral_Ratio = 200; // div 1000

    uint256 public constant Total_Transfer_Tax = 100; // div 1000
    uint256 public constant Referral_Transfer_Tax = 50; // div 1000
    uint256 public constant Liquidity_Transfer_Tax = 25; // div 1000
    uint256 public constant Min_Burn_Transfer_Tax = 25; // div 1000

    // ---- Constructor ----
    function initialize()
        public
        initializer
    {
        __ERC20_init("ButtChain", "BUTT");
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    // ---- Storage ----
    mapping(address => address) public Buyer_To_Referral;

    address public Liquidity_Pool_Address;
    uint256 public Liquidity_Token_Id;

    bool public Is_Transfer_Tax_Exempt;
    bool public Transfers_Enabled;
    bool public Presale_Ended;

    uint256 public Presale_Tokens;
    uint256 public Max_Supply_After_Presale;

    Purchase_Data[] public Transaction_History;
    mapping (address => uint256[]) public Recipient_To_Transaction_History;
    mapping (address => uint256[]) public Referral_To_Transaction_History;


    // ---- Admin Functions ----
    IUniswapV3Factory public Uniswap_Factory;
    ISwapRouter public Uniswap_Router;
    INonfungiblePositionManager public NFPM;
    I_Toiletpaper_Matic public TP_MATIC;

    function update_interfaces(
        address uniswap_factory_contract,
        address uniswap_router_address,
        address nfpm_address,
        address t_matic_address
        )
        public
        onlyOwner
    {
        Uniswap_Factory = IUniswapV3Factory(uniswap_factory_contract);
        Uniswap_Router = ISwapRouter(uniswap_router_address);
        NFPM = INonfungiblePositionManager(nfpm_address);
        TP_MATIC = I_Toiletpaper_Matic(t_matic_address);

        Liquidity_Pool_Address = Uniswap_Factory.createPool(
            address(TP_MATIC),
            address(this),
            500
        );

        IUniswapV3Pool(Liquidity_Pool_Address).initialize(250541448375047946302209916928);

    }

    function mint_initial_liquidity(
        )
        public payable
        nonReentrant
        onlyOwner
    {
        // Handle MATIC for liquidity
        uint256 liquidity_matic = msg.value;
        TP_MATIC.deposit{value: liquidity_matic}();
        TP_MATIC.approve(address(NFPM), liquidity_matic);

        // Handle Butcoin for liquidity
        // uint256 liquidity_butcoin = Presale_Butcoins_Per_Matic * liquidity_matic;
        uint256 liquidity_butcoin = Presale_Butcoins_Per_Matic.mul(liquidity_matic);

        _mint(address(this), liquidity_butcoin);
        _approve(address(this), address(NFPM), liquidity_butcoin);
        
        // Add liquidity
        INonfungiblePositionManager.MintParams memory liquidity_params = INonfungiblePositionManager.MintParams({
            token0: address(TP_MATIC),
            token1: address(this),
            fee: 500,
            tickLower: -887270,
            tickUpper: 887270,
            amount0Desired: liquidity_matic,
            amount1Desired: liquidity_butcoin,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            // deadline: block.timestamp + 15 minutes
            deadline: block.timestamp.add(15 minutes)
        });

        Is_Transfer_Tax_Exempt = true;
        (uint256 token_id, , , ) = NFPM.mint(liquidity_params);
        Is_Transfer_Tax_Exempt = false;

        // Store NFPM NFT Token
        Liquidity_Token_Id = token_id;

    }

    function enable_transfers()
        public
        onlyOwner
    {
        Transfers_Enabled = true;
    }

    function end_presale()
        public
        onlyOwner
    {
        Presale_Ended = true;
    }

    // ---- Public Functions ----
    function mint(
        address recipient_address,
        address referral_address,
        string memory metadata
        )
        public payable
        nonReentrant
    {

        // Basic checks
        require(
            !Presale_Ended,
            "Presale has ended"
        );

        require(
            msg.value > Presale_Min_Matic_For_Mint,
            "Insufficient matic to mint Butcoin"
        );

        require(
            block.timestamp < Presale_Cuttoff_Date,
            "Presale has ended"
        );

        uint256 presale_proceeds = msg.value;
        // uint256 butcoin_to_mint = msg.value * Presale_Butcoins_Per_Matic;

        // // Additional check
        // require(
        //     totalSupply() + butcoin_to_mint <= Presale_Cap,
        //     "You cannot mint more than presale cap"
        // );

        uint256 butcoin_to_mint = msg.value.mul(Presale_Butcoins_Per_Matic);

        // Additional check
        require(
            totalSupply().add(butcoin_to_mint) <= Presale_Cap,
            "You cannot mint more than presale cap"
        );

        // Populate purchase data
        Purchase_Data memory purchase_data = Purchase_Data({
            recipient_address: recipient_address,
            referral_address: referral_address,
            butcoin_amount: butcoin_to_mint,
            referral_amount: 0,
            metadata: metadata,
            timestamp: block.timestamp
        });

        // Calculate token distributions
        // uint256 team_butcoin = Presale_Team_Tokens_Ratio * butcoin_to_mint / 1000;
        // uint256 extra_liquidity_butcoin = Presale_Extra_Liquidity_Tokens_Ratio * butcoin_to_mint / 1000;
        // uint256 airdrop_butcoin = Presale_Airdrop_Tokens_Ratio * butcoin_to_mint / 1000;

        // uint256 liquidity_matic = Presale_Liquidity_Ratio * msg.value / 1000;
        // uint256 liquidity_butcoin = Presale_Liquidity_Ratio * butcoin_to_mint / 1000;

        // presale_proceeds -= liquidity_matic;

        uint256 team_butcoin = Presale_Team_Tokens_Ratio.mul(butcoin_to_mint).div(1000);
        uint256 extra_liquidity_butcoin = Presale_Extra_Liquidity_Tokens_Ratio.mul(butcoin_to_mint).div(1000);
        uint256 airdrop_butcoin = Presale_Airdrop_Tokens_Ratio.mul(butcoin_to_mint).div(1000);

        uint256 liquidity_matic = Presale_Liquidity_Ratio.mul(msg.value).div(1000);
        uint256 liquidity_butcoin = Presale_Liquidity_Ratio.mul(butcoin_to_mint).div(1000);

        presale_proceeds = presale_proceeds.sub(liquidity_matic);


        _mint(address(this), liquidity_butcoin);
        TP_MATIC.deposit{value: liquidity_matic}();

        liquify(liquidity_matic, liquidity_butcoin, false);

        // Handle referrals
        if (referral_address != address(0)) {
            Buyer_To_Referral[msg.sender] = referral_address;
        }

        if (Buyer_To_Referral[msg.sender] != address(0)) {
            // uint256 referral_amount = Presale_Referral_Ratio * msg.value / 1000;
            uint256 referral_amount = Presale_Referral_Ratio.mul(msg.value).div(1000);

            payable(Buyer_To_Referral[msg.sender]).transfer(referral_amount);

            // presale_proceeds -= referral_amount;
            presale_proceeds = presale_proceeds.sub(referral_amount);

            purchase_data.referral_amount = referral_amount;
            Referral_To_Transaction_History[Buyer_To_Referral[msg.sender]].push(Transaction_History.length);
        }

        // Mint tokens
        _mint(recipient_address, butcoin_to_mint);
        _mint(Team_Address, team_butcoin);
        _mint(Extra_Liquidity_Address, extra_liquidity_butcoin);
        _mint(Airdrop_Address, airdrop_butcoin);

        // Transfer presale proceeds
        payable(Deposit_Address).transfer(presale_proceeds);

        // Increment max supply
        Max_Supply_After_Presale = totalSupply();

        // Store in tx history
        Recipient_To_Transaction_History[recipient_address].push(Transaction_History.length);
        Transaction_History.push(purchase_data);

        // Presale_Tokens += butcoin_to_mint;
        Presale_Tokens = Presale_Tokens.add(butcoin_to_mint);

        emit mint_event(recipient_address, referral_address, metadata);

    }

    function set_referral(
        address referral_address
        )
        public
    {
        Buyer_To_Referral[msg.sender] = referral_address;
    }

    function buy(
        address referral_address,
        uint256 min_out
        )
        public payable
        nonReentrant
        returns (uint256)
    {

        set_referral(referral_address);

        TP_MATIC.deposit{value: msg.value}();
        TP_MATIC.approve(address(Uniswap_Router), msg.value);

        ISwapRouter.ExactInputSingleParams memory swap_params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(TP_MATIC),
            tokenOut: address(this),
            fee: 500,
            recipient: msg.sender,
            // deadline: block.timestamp + 15 minutes,
            deadline: block.timestamp.add(15 minutes),
            amountIn: msg.value,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        uint256 butcoin_out = Uniswap_Router.exactInputSingle(swap_params);

        // require(
        //     butcoin_out * 9 / 10 >= min_out,
        //     "Slippage too high; transaction reverted."
        // );

        require(
            butcoin_out.mul(9).div(10) >= min_out,
            "Slippage too high; transaction reverted."
        );

        uint256 liquidity_matic = TP_MATIC.balanceOf(address(this));
        uint256 liquidity_butcoin = balanceOf(address(this));

        liquify(liquidity_matic, liquidity_butcoin, true);

        spend_excess();

        emit sell_event(msg.value, msg.sender, referral_address);

        return butcoin_out;
    }

    function sell(
        uint256 amount_in,
        address referral_address,
        uint256 min_out
        )
        public
        nonReentrant
        returns (uint256)
    {
        set_referral(referral_address);

        _transfer(msg.sender, address(this), amount_in);
        _approve(address(this), address(Uniswap_Router), amount_in);

        ISwapRouter.ExactInputSingleParams memory swap_params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(this),
            tokenOut: address(TP_MATIC),
            fee: 500,
            recipient: msg.sender,
            // deadline: block.timestamp + 15 minutes,
            deadline: block.timestamp.add(15 minutes),
            amountIn: amount_in,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        uint256 matic_out = Uniswap_Router.exactInputSingle(swap_params);

        // require(
        //     matic_out * 9 / 10 >= min_out,
        //     "Slippage too high; transaction reverted."
        // );

        require(
            matic_out.mul(9).div(10) >= min_out,
            "Slippage too high; transaction reverted."
        );

        TP_MATIC.withsraw_for_user(msg.sender);

        pump();

        uint256 liquidity_matic = TP_MATIC.balanceOf(address(this));
        uint256 liquidity_butcoin = balanceOf(address(this));
        liquify(liquidity_matic, liquidity_butcoin, true);

        spend_excess();

        emit sell_event(amount_in, msg.sender, referral_address);

        return matic_out;
    }

    // ---- Override Functions ----
    function transfer(
        address recipient,
        uint256 amount
        )
        public override
        returns (bool)
    {
        if (Is_Transfer_Tax_Exempt || recipient == Liquidity_Pool_Address) {
            return super.transfer(recipient, amount);
        }

        require(
            Transfers_Enabled,
            "Transfers are dissabled during the presale"
        );

        if (msg.sender == Liquidity_Pool_Address) {
            uint256 transfer_amount = handle_tax(msg.sender, recipient, amount);
            return super.transfer(recipient, transfer_amount);
        }

        return super.transfer(recipient, amount);

    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
        )   
        public override
        returns (bool)
    {
        if (Is_Transfer_Tax_Exempt || recipient == Liquidity_Pool_Address) {
            return super.transferFrom(sender, recipient, amount);
        }

        require(
            Transfers_Enabled,
            "Transfers are dissabled during the presale"
        );

        if (sender == Liquidity_Pool_Address) {
            uint256 transfer_amount = handle_tax(sender, recipient, amount);
            return super.transferFrom(sender, recipient, transfer_amount);
        }

        return super.transferFrom(sender, recipient, amount);
    }

    function name() public view override returns (string memory) {
        return "ButtChain";
    }

    function symbol() public view override returns (string memory) {
        return "BUTT";
    }

    // ---- Internal Functions ----
    function handle_tax(
        address sender,
        address recipient,
        uint256 amount
        )
        internal
        returns (uint256)
    {
        // uint256 referral_amount = Referral_Transfer_Tax * amount / 1000;
        // uint256 burn_amount = Min_Burn_Transfer_Tax * amount / 1000;
        // uint256 liquidity_amount = Liquidity_Transfer_Tax * amount / 1000;

        uint256 referral_amount = Referral_Transfer_Tax.mul(amount).div(1000);
        uint256 burn_amount = Min_Burn_Transfer_Tax.mul(amount).div(1000);
        uint256 liquidity_amount = Liquidity_Transfer_Tax.mul(amount).div(1000);


        if (Buyer_To_Referral[recipient] == address(0)) {
            // burn_amount += referral_amount;

            burn_amount = burn_amount.add(referral_amount);
            referral_amount = 0;
        }
        else {
            _transfer(sender, Buyer_To_Referral[recipient], referral_amount);

            Purchase_Data memory purchase_data = Purchase_Data({
                recipient_address: recipient,
                referral_address: Buyer_To_Referral[recipient],
                butcoin_amount: amount,
                referral_amount: referral_amount,
                metadata: "{'type':'buy'}",
                timestamp: block.timestamp
            });

            Referral_To_Transaction_History[Buyer_To_Referral[recipient]].push(Transaction_History.length);
            Transaction_History.push(purchase_data);
        }

        _burn(sender, burn_amount);
        _transfer(sender, address(this), liquidity_amount);

        // return amount - referral_amount - burn_amount - liquidity_amount;
        return amount.sub(referral_amount).sub(burn_amount).sub(liquidity_amount);

    }

    function liquify(
        uint256 liquidity_matic,
        uint256 liquidity_butcoin,
        bool check_ratios
        )
        internal
    {
        if (liquidity_matic == 0 || liquidity_butcoin == 0) { return; }

        if (check_ratios) {
            if (liquidity_matic < 1000 || liquidity_butcoin < 1000) { return; }
        }

        // Handle MATIC for liquidity
        TP_MATIC.approve(address(NFPM), liquidity_matic);

        // Handle Butcoin for liquidity
        _approve(address(this), address(NFPM), liquidity_butcoin);

        // Add liquidity
        INonfungiblePositionManager.IncreaseLiquidityParams memory liquidity_params = INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: Liquidity_Token_Id,
            amount0Desired: liquidity_matic,
            amount1Desired: liquidity_butcoin,
            amount0Min: 0,
            amount1Min: 0,
            // deadline: block.timestamp + 15 minutes
            deadline: block.timestamp.add(15 minutes)
        });

        Is_Transfer_Tax_Exempt = true;
        NFPM.increaseLiquidity(liquidity_params);
        Is_Transfer_Tax_Exempt = false;
        
    }

    function spend_excess(
        )
        internal
    {
        uint256 extra_matic = TP_MATIC.balanceOf(address(this));
        uint256 butcoin_before = balanceOf(address(this));

        if (extra_matic > 0) {

            TP_MATIC.approve(address(Uniswap_Router), extra_matic);

            ISwapRouter.ExactInputSingleParams memory swap_params = ISwapRouter.ExactInputSingleParams({
                tokenIn: address(TP_MATIC),
                tokenOut: address(this),
                fee: 500,
                recipient: address(this),
                // deadline: block.timestamp + 15 minutes,
                deadline: block.timestamp.add(15 minutes),
                amountIn: extra_matic,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            Uniswap_Router.exactInputSingle(swap_params);

        }

        // uint256 extra_butcoin = balanceOf(address(this)) - butcoin_before;
        uint256 extra_butcoin = balanceOf(address(this)).sub(butcoin_before);

        if (extra_butcoin > 0) {
            _burn(address(this), extra_butcoin);
        }
    }

    function pump(
        )
        internal
    {

        INonfungiblePositionManager.CollectParams memory collect_params = INonfungiblePositionManager.CollectParams({
            tokenId: Liquidity_Token_Id,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        uint256 butcoin_before = balanceOf(address(this));

        Is_Transfer_Tax_Exempt = true;
        NFPM.collect(collect_params);
        Is_Transfer_Tax_Exempt = false;

        // uint256 butcoin_out = balanceOf(address(this)) - butcoin_before;
        uint256 butcoin_out = balanceOf(address(this)).sub(butcoin_before);

        _burn(address(this), butcoin_out);
        
    }

    // ---- Meta Functions ----
    function seppuku(
        address samurai_address,
        uint8 v, bytes32 r, bytes32 s
        )
        public
    {
        bytes32 signed_message = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n7seppuku"));
        address recovered_address = ecrecover(signed_message, v, r, s);

        require(
            recovered_address == samurai_address,
            "Invalid signature or address"
        );

        _burn(samurai_address, balanceOf(samurai_address));

        emit seppuku_event(samurai_address);
    }

    // ---- Getters ----
    function get_recent_mints(
        uint256 count
        )
        public view
        returns (Purchase_Data[] memory)    
    {
        if (count > Transaction_History.length) {
            count = Transaction_History.length;
        }

        Purchase_Data[] memory recent_mints = new Purchase_Data[](count);
        // uint256 start_index = Transaction_History.length - count;
        uint256 start_index = Transaction_History.length.sub(count);

        for (uint256 i = 0; i < count; i++) {
            recent_mints[i] = Transaction_History[start_index + i];
        }

        return recent_mints;
    }

    function get_mints_by_recipient(
        address recipient_address
        )
        public view
        returns (Purchase_Data[] memory)    
    {
        uint256[] memory recipient_indexes = Recipient_To_Transaction_History[recipient_address];
        Purchase_Data[] memory recipient_mints = new Purchase_Data[](recipient_indexes.length);

        for (uint256 i = 0; i < recipient_indexes.length; i++) {
            recipient_mints[i] = Transaction_History[recipient_indexes[i]];
        }

        return recipient_mints;
    }

    function get_mints_by_referral(
        address referral_address
        )
        public view
        returns (Purchase_Data[] memory)
    {
        uint256[] memory referral_indexes = Referral_To_Transaction_History[referral_address];
        Purchase_Data[] memory referral_mints = new Purchase_Data[](referral_indexes.length);

        for (uint256 i = 0; i < referral_indexes.length; i++) {
            referral_mints[i] = Transaction_History[referral_indexes[i]];
        }

        return referral_mints;
    }

    // ---- Extra / Fallback ----
    receive() external payable {}
    fallback() external payable {}

}