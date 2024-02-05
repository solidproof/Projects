// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract LuckyCoin is ERC20Burnable {
    //The weekly interest rate: 0.25%
    uint256 constant WEEKLY_INTEREST_RATE_X10000 = 25;

    //The weekly deflation rate: 0.25%
    uint256 constant WEEKLY_DEFLATION_RATE_X10000 = 25;

    //The minimum random mint rate: 100% = 1x
    uint256 constant MINIMUM_MINT_RATE_X100 = 1e2;

    //The maximum random mint rate: 100,000% = 1,000x
    uint256 constant MAXIMUM_MINT_RATE_X100 = 1e5;

    //The maximum random mint amount relative to the total coin amount: 5%
    uint256 constant MAX_MINT_TOTAL_AMOUNT_RATE_X100 = 5;

    //The coin amount for the initial minting: 100,000,000
    uint256 constant INITIAL_MINT_AMOUNT = 1e26;

    //The minimum total supply: 1,000,000
    uint256 constant MINIMUM_TOTAL_SUPPLY = 1e24;

    //Time interval for random mint
    uint256 constant RANDOM_MINT_MIN_INTERVAL = 1 weeks - 1 minutes;

    //Timeout for random mint
    uint256 constant RANDOM_MINT_TIMEOUT = 1 days;

    //Minimum number of total addresses required to run the
    //random mint
    uint256 constant RANDOM_MINT_MIN_TOTAL_ADDRESSES = 100;

    //Dead address for token burning
    address constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    //Number of bits for the random number generation
    uint8 constant RANDOM_NUM_BITS = 32;

    //The maximum burn rate for each transaction: 10%
    uint256 constant MAXIMUM_TRANSACTION_BURN_RATE_X10000 = 1000;

    //The smoothing factor for the calculation of the exponential moving average of the mean volume: 0.1
    uint256 constant MEAN_VOLUME_SMOOTHING_FACTOR_X10000 = 1000;

    //the maximum single trade volume in relation to total supply: 5%
    uint256 constant MAXIMUM_SINGLE_TRADE_VOLUME_X10000 = 500;

    //the time horizon multiplicator: 0.9 (1 year)
    uint256 constant BURN_RATE_TIME_HORIZON_MULTIPLICATOR_X10000 = 9000;

    //initial estimation of the weekly volume: 15%
    uint256 constant INITIAL_MEAN_WEEK_VOLUME_X10000 = 1500;

    //amount of burn under expected total supply: 2%
    uint256 constant MAXIMUM_WEEK_BURN_EXCESS_X10000 = 200;

    //Total number of addresses with amount > 0
    uint256 public totalAddresses;

    //Mapping from index to address
    mapping(uint256 => address) private indexToAddress;

    //Mapping from address to index
    mapping(address => uint256) private addressToIndex;

    //Timestamp of the start of last random mint
    uint256 public randomMintLastTimeStamp;

    //Block number of the start of last random mint
    uint256 public randomMintStartBlockNumber;

    //The burn rate for each transaction
    uint256 public transactionBurnRateX10000;

    //The current week trade volume
    uint256 public currentWeekVolume;

    //The current week burn amount
    uint256 public currentWeekBurnAmount;

    //The mean week trade volume divided by the total supply
    uint256 public meanWeekVolumeX10000;

    //The expected total supply
    uint256 public expectedSupply;

    //The maximum burn amount for the current week
    uint256 public maximumWeekBurnAmount;

    //Constructor
    constructor() ERC20("LuckyCoin", "LCK") {
        totalAddresses = 0;
        randomMintLastTimeStamp = 0;
        randomMintStartBlockNumber = 0;
        transactionBurnRateX10000 = 0;
        currentWeekVolume = 0;
        meanWeekVolumeX10000 = INITIAL_MEAN_WEEK_VOLUME_X10000;
        expectedSupply = INITIAL_MINT_AMOUNT;
        maximumWeekBurnAmount = 0;
        currentWeekBurnAmount = 0;
        _mint(msg.sender, INITIAL_MINT_AMOUNT);
    }

    //Public function to start the random mint,
    //Checks the requirements and starts the private function
    function randomMintStart() external {
        require(
            block.timestamp >
                randomMintLastTimeStamp + RANDOM_MINT_MIN_INTERVAL,
            "You have to wait one week after the last random mint"
        );
        require(
            !(randomMintStartBlockNumber > 0),
            "Random mint already started"
        );
        require(
            randomMintLastTimeStamp > 0,
            "Minimum number of addresses has not been reached"
        );
        _randomMintStart();
    }

    //Private function to start the random mint
    //It just sets the initial timestamp and block number
    //(this will stop all transactions until the end of random mint)
    function _randomMintStart() internal {
        randomMintLastTimeStamp = block.timestamp;
        randomMintStartBlockNumber = block.number;
    }

    //Public function to end the random mint
    //Checks the requirements and starts the private function
    function randomMintEnd() external {
        require(randomMintStartBlockNumber > 0, "Random mint not started");
        require(
            block.number > randomMintStartBlockNumber + RANDOM_NUM_BITS + 1,
            "You have to wait 32 blocks after start"
        );
        _randomMintEnd();
    }

    //Private function to end the random mint
    //Random mint and update of the burn rate
    function _randomMintEnd() internal {
        //reset state
        randomMintStartBlockNumber = 0;

        //check timeout
        if (block.timestamp < randomMintLastTimeStamp + RANDOM_MINT_TIMEOUT) {
            //random mint
            _randomMint();

            //update burn rate
            _updateBurnRate();
        }
    }

    //Updates the burn rate
    function _updateBurnRate() internal {
        uint256 RealTotalSupply = realTotalSupply();

        //update mean volume
        meanWeekVolumeX10000 =
            (MEAN_VOLUME_SMOOTHING_FACTOR_X10000 * currentWeekVolume) /
            RealTotalSupply +
            ((10000 - MEAN_VOLUME_SMOOTHING_FACTOR_X10000) *
                meanWeekVolumeX10000) /
            10000;

        //reset weekly totals
        currentWeekVolume = 0;
        currentWeekBurnAmount = 0;

        //update expected supply
        expectedSupply = max(
            (expectedSupply * (10000 - WEEKLY_DEFLATION_RATE_X10000)) / 10000,
            MINIMUM_TOTAL_SUPPLY
        );

        //update burn rate
        if (RealTotalSupply > expectedSupply) {
            transactionBurnRateX10000 = min(
                (100000000 -
                    (BURN_RATE_TIME_HORIZON_MULTIPLICATOR_X10000 +
                        ((10000 - BURN_RATE_TIME_HORIZON_MULTIPLICATOR_X10000) *
                            expectedSupply) /
                        RealTotalSupply) *
                    (10000 -
                        WEEKLY_INTEREST_RATE_X10000 -
                        WEEKLY_DEFLATION_RATE_X10000)) /
                    max(meanWeekVolumeX10000, 1),
                MAXIMUM_TRANSACTION_BURN_RATE_X10000
            );
            maximumWeekBurnAmount =
                RealTotalSupply -
                expectedSupply +
                (expectedSupply * MAXIMUM_WEEK_BURN_EXCESS_X10000) /
                10000;
        } else {
            transactionBurnRateX10000 = 0;
            maximumWeekBurnAmount = 0;
        }
    }

    //Generation of random wallet index, computation of the mint amount and mint operation
    function _randomMint() internal {
        //calculate random wallet index
        uint256 selectedIndex = generateSafePRNG(
            RANDOM_NUM_BITS,
            totalAddresses
        ) + 1;
        //calculate mint rate
        uint256 mintRateX100 = (totalAddresses * WEEKLY_INTEREST_RATE_X10000) /
            100;
        //calculate number of selected wallets
        uint256 numSelected = (mintRateX100 - 1) /
            MAXIMUM_MINT_RATE_X100 +
            1;
        while (mintRateX100 > 0) {
            //get random wallet address
            address selectedAddress = indexToAddress[selectedIndex];
            //calculate mint amount
            uint256 mintAmount = (balanceOf(selectedAddress) *
                min(
                    max(mintRateX100, MINIMUM_MINT_RATE_X100),
                    MAXIMUM_MINT_RATE_X100
                )) / 100;
            //limit max mint amount
            mintAmount = min(
                mintAmount,
                (realTotalSupply() * MAX_MINT_TOTAL_AMOUNT_RATE_X100) / 100
            );
            //mint
            if (mintAmount > 0 && !isContract(selectedAddress))
                _mint(selectedAddress, mintAmount);
            //next address
            selectedIndex += totalAddresses / numSelected;
            if (selectedIndex > totalAddresses) selectedIndex -= totalAddresses;
            //decrease mint rate
            mintRateX100 -= min(mintRateX100, MAXIMUM_MINT_RATE_X100);
        }
    }

    //Callback function before token transfer
    //Checks if the random mint is in progress and automatically starts/stops it
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (randomMintStartBlockNumber == 0) {
            //random mint not in progress
            if (
                block.timestamp >
                randomMintLastTimeStamp + RANDOM_MINT_MIN_INTERVAL &&
                randomMintLastTimeStamp > 0
            ) {
                //start random mint
                _randomMintStart();
            }
        } else {
            //random mint in progress
            if (
                block.number > randomMintStartBlockNumber + RANDOM_NUM_BITS + 1
            ) {
                //end random mint
                _randomMintEnd();
            } else {
                //error (but allow token transfers in this block)
                if (block.number > randomMintStartBlockNumber)
                    revert(
                        "Random mint in progress, transactions are suspended"
                    );
            }
        }
    }

    //Callback function after token transfer
    //Updates the wallet count and the mapping from index to address and from address to index
    //Removes a wallet if it becomes empty and adds add a new wallet if it becomes full
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);

        if (amount == 0 || from == to) return;

        // insert receiver in mapping
        if (
            to != address(0) &&
            to != DEAD_ADDRESS &&
            balanceOf(to) == amount &&
            !isContract(to)
        ) {
            // increment number of addresses
            totalAddresses++;
            // insert address in mapping
            indexToAddress[totalAddresses] = to;
            addressToIndex[to] = totalAddresses;
            //enable random mint
            if (
                randomMintLastTimeStamp == 0 &&
                totalAddresses >= RANDOM_MINT_MIN_TOTAL_ADDRESSES
            ) {
                randomMintLastTimeStamp = block.timestamp;
                expectedSupply = realTotalSupply();
            }
        }

        // remove sender from mapping
        if (
            from != address(0) && from != DEAD_ADDRESS && balanceOf(from) == 0
        ) {
            // read index of sender
            uint256 fromIndex = addressToIndex[from];
            if (fromIndex > 0) {
                //read address for last index
                address lastAddress = indexToAddress[totalAddresses];
                // remove address from mapping
                indexToAddress[fromIndex] = lastAddress;
                addressToIndex[lastAddress] = fromIndex;
                addressToIndex[from] = 0;
                // decrement number of addresses
                totalAddresses--;
            }
        }
    }

    //Override for _transfer function
    //Performs token burning
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        //calculate burn amount
        uint256 burnAmount = 0;
        if (currentWeekBurnAmount < maximumWeekBurnAmount) {
            burnAmount = (transactionBurnRateX10000 * amount) / 10000;
            if (currentWeekBurnAmount + burnAmount > maximumWeekBurnAmount)
                burnAmount = maximumWeekBurnAmount - currentWeekBurnAmount;
        }
        //burn
        if (burnAmount > 0) _burn(from, burnAmount);
        //transfer
        super._transfer(from, to, amount - burnAmount);
        //update weekly totals
        if (randomMintLastTimeStamp > 0) {
            currentWeekVolume += min(
                amount,
                (MAXIMUM_SINGLE_TRADE_VOLUME_X10000 * realTotalSupply()) / 10000
            );
            currentWeekBurnAmount += burnAmount;
        }
    }

    //Returns the total supply minus the burned tokens
    function realTotalSupply() public view returns (uint256) {
        return totalSupply() - balanceOf(DEAD_ADDRESS);
    }

    //Calculates the minimum of two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    //Calculates the maximum of two numbers
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    //Calculates a pseudorandom number taking 1 bit from each previous block
    //The generated pseudorandom number is in the range [0 : maxValue - 1]
    function generateSafePRNG(uint8 numBlocks, uint256 maxValue)
        internal
        view
        returns (uint256)
    {
        //initialize
        uint256 rnd = uint256(blockhash(block.number - numBlocks - 1)) <<
            numBlocks;
        //take 1 bit from the last blocks
        for (uint8 i = 0; i < numBlocks; i++)
            rnd |= (uint256(blockhash(block.number - i - 1)) & 0x01) << i;
        //hash
        rnd = uint256(keccak256(abi.encodePacked(rnd)));
        //limit to max and return
        return rnd - maxValue * (rnd / maxValue);
    }

    //Tells if the address is a contract
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

}
