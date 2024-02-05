//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "./Authorizable.sol";
import "./BonsaiV1.sol";
import "./AirV1.sol";
// import "hardhat/console.sol";

contract WaterV1 is ERC20, Authorizable {
    using SafeMath for uint256;

    uint256 public MAX_WATER_SUPPLY = 32000000000000000000000000000;
    string private TOKEN_NAME = "water";
    string private TOKEN_SYMBOL = "WTR";

    address public BONSAI_CONTRACT;
    address public AIR_CONTRACT;

    uint256 public BOOSTER_MULTIPLIER = 1;
    uint256 public WATER_FARMING_FACTOR = 3; // air to water ratio
    uint256 public WATER_SWAP_FACTOR = 12; // swap air for water ratio

    // Moved "SKIP_COOLDOWN_BASE" to AirV1 contract
    // Moved "SKIP_COOLDOWN_BASE_FACTOR" to AirV1 contract

    // water mint event
    event Minted(address owner, uint256 numberOfWater);
    event Burned(address owner, uint256 numberOfWater);
    event AirSwap(address owner, uint256 numberOfWater);
    // air event
    event MintedAir(address owner, uint256 numberOfWater);
    event BurnedAir(address owner, uint256 numberOfAirs);
    event StakedAir(address owner, uint256 numberOfAirs);
    event UnstakedAir(address owner, uint256 numberOfAirs);

    // Air staking
    struct AirStake {
        // user wallet - who we have to pay back for the staked air.
        address user;
        // used to calculate how much water since.
        uint32 since;
        // amount of airs that have been staked.
        uint256 amount;
    }

    mapping(address => AirStake) public airStakeHolders;
    uint256 public totalAirStaked;
    address[] public _allAirsStakeHolders;
    mapping(address => uint256) private _allAirsStakeHoldersIndex;

    // air stake and unstake
    event AirStaked(address user, uint256 amount);
    event AirUnStaked(address user, uint256 amount);

    constructor(address _bonsaiContract, address _airContract)
        ERC20(TOKEN_NAME, TOKEN_SYMBOL)
    {
        BONSAI_CONTRACT = _bonsaiContract;
        AIR_CONTRACT = _airContract;
    }

    /**
     * updates user's amount of staked air to the given value. Resets the "since" timestamp.
     */


    function _upsertAirStaking(
        address user,
        uint256 amount
    ) internal {
        // NOTE does this ever happen?
        require(user != address(0), "EMPTY ADDRESS");
        AirStake memory air = airStakeHolders[user];

        // if first time user is staking $air...
        if (air.user == address(0)) {
            // add tracker for first time staker
            _allAirsStakeHoldersIndex[user] = _allAirsStakeHolders.length;
            _allAirsStakeHolders.push(user);
        }
        // since its an upsert, we took out old air and add new amount
        uint256 previousAirs = air.amount;
        // update stake
        air.user = user;
        air.amount = amount;
        air.since = uint32(block.timestamp);

        airStakeHolders[user] = air;
        totalAirStaked = totalAirStaked - previousAirs + amount;
        emit AirStaked(user, amount);
    }

    function staking(uint256 amount) external {
        require(amount > 0, "NEED AIR");
        AirV1 airContract = AirV1(AIR_CONTRACT);
        uint256 available = airContract.balanceOf(msg.sender);
        require(available >= amount, "NOT ENOUGH AIR");
        AirStake memory existingAir = airStakeHolders[msg.sender];
        if (existingAir.amount > 0) {
            // already have previous air staked
            // need to calculate claimable
            uint256 projection = claimableView(msg.sender);
            // mint water to wallet
            _mint(msg.sender, projection);
            emit Minted(msg.sender, amount);
            _upsertAirStaking(msg.sender, existingAir.amount + amount);
        } else {
            // no air staked just update staking
            _upsertAirStaking(msg.sender, amount);
        }
        airContract.burnAir(msg.sender, amount);
        emit StakedAir(msg.sender, amount);
    }

    /**
     * Calculates how much water is available to claim.
     */
    function claimableView(address user) public view returns (uint256) {
        AirStake memory air = airStakeHolders[user];
        require(air.user != address(0), "NOT STAKED");
        // need to add 10000000000 to factor for decimal
        return
            ((air.amount * WATER_FARMING_FACTOR) *
                (((block.timestamp - air.since) * 10000000000) / 86400) *
                BOOSTER_MULTIPLIER) /
            10000000000;
    }

    // NOTE withdrawing air without claiming water
    function withdrawAir(uint256 amount) external {
        require(amount > 0, "MUST BE MORE THAN 0");
        AirStake memory air = airStakeHolders[msg.sender];
        require(air.user != address(0), "NOT STAKED");
        require(amount <= air.amount, "OVERDRAWN");
        AirV1 airContract = AirV1(AIR_CONTRACT);
        // uint256 projection = claimableView(msg.sender);
        _upsertAirStaking(msg.sender, air.amount - amount);
        // Need to burn 1/12 when withdrawing (spillage fee)
        uint256 afterBurned = (amount * 11) / 12;
        // mint air to return to user
        airContract.mintAir(msg.sender, afterBurned);
        emit UnstakedAir(msg.sender, afterBurned);
    }

    /**
     * Claims water from staked Air
     */
    function claimWater() external {
        uint256 projection = claimableView(msg.sender);
        require(projection > 0, "NO WATER TO CLAIM");

        AirStake memory air = airStakeHolders[msg.sender];

        // Updates user's amount of staked airs to the given value. Resets the "since" timestamp.
        _upsertAirStaking(msg.sender, air.amount);

        // check: that the total Water supply hasn't been exceeded.
        _mintWater(msg.sender, projection);
    }

    /**
     */
    function _removeUserFromAirEnumeration(address user) private {
        uint256 lastUserIndex = _allAirsStakeHolders.length - 1;
        uint256 currentUserIndex = _allAirsStakeHoldersIndex[user];

        address lastUser = _allAirsStakeHolders[lastUserIndex];

        _allAirsStakeHolders[currentUserIndex] = lastUser; // Move the last token to the slot of the to-delete token
        _allAirsStakeHoldersIndex[lastUser] = currentUserIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allAirsStakeHoldersIndex[user];
        _allAirsStakeHolders.pop();
    }

    /**
     * Unstakes the airs, returns the Airs (mints) to the user.
     */
    function withdrawAllAirAndClaimWater() external {
        AirStake memory air = airStakeHolders[msg.sender];

        // NOTE does this ever happen?
        require(air.user != address(0), "NOT STAKED");

        // if there's water to claim, supply it to the owner...
        uint256 projection = claimableView(msg.sender);
        if (projection > 0) {
            // supply water to the sender...
            _mintWater(msg.sender, projection);
        }
        // if there's air to withdraw, supply it to the owner...
        if (air.amount > 0) {
            // mint air to return to user
            // Need to burn 1/12 when withdrawing (breakage fee)
            uint256 afterBurned = (air.amount * 11) / 12;
            AirV1 airContract = AirV1(AIR_CONTRACT);
            airContract.mintAir(msg.sender, afterBurned);
            emit UnstakedAir(msg.sender, afterBurned);
        }
        // Internal: removes air from storage.
        _unstakingAir(msg.sender);
    }

    /**
     * Internal: removes air from storage.
     */
    function _unstakingAir(address user) internal {
        AirStake memory air = airStakeHolders[user];
        // NOTE when whould address be zero?
        require(air.user != address(0), "EMPTY ADDRESS");
        totalAirStaked = totalAirStaked - air.amount;
        _removeUserFromAirEnumeration(user);
        delete airStakeHolders[user];
        emit AirUnStaked(user, air.amount);
    }

    /**
     * Waters the bonsai the amount of Water.
     */
    function waterBonsai(uint256 bonsaiId, uint256 amount) external {
        // check: amount is gt zero...
        require(amount > 0, "MUST BE MORE THAN 0 WATER");

        IERC721 instance = IERC721(BONSAI_CONTRACT);

        // check: msg.sender is bonsai owner...
        require(instance.ownerOf(bonsaiId) == msg.sender, "NOT OWNER");

        // check: user has enough water in wallet...
        require(balanceOf(msg.sender) >= amount, "NOT ENOUGH WATER");

        // TODO should this be moved to air contract? or does the order here, matter?
        AirV1 airContract = AirV1(AIR_CONTRACT);
        (uint24 cm, , , , ) = airContract.stakedBonsai(bonsaiId);
        require(cm > 0, "NOT STAKED");

        // burn water...

        _burn(msg.sender, amount);

        emit Burned(msg.sender, amount);


        // update eatenAmount in AirV1 contract...
        airContract.waterBonsai(bonsaiId, amount);
    }

    // Moved "levelup" to the AirV1 contract - it doesn't need anything from Water contract.

    // Moved "skipCoolingOff" to the AirV1 contract - it doesn't need anything from Water contract.

    function swapAirForWater(uint256 airAmt) external {
        require(airAmt > 0, "MUST BE MORE THAN 0 AIR");

        // burn airs...
        AirV1 airContract = AirV1(AIR_CONTRACT);
        airContract.burnAir(msg.sender, airAmt);

        // supply water...
        _mint(msg.sender, airAmt * WATER_SWAP_FACTOR);
        emit AirSwap(msg.sender, airAmt * WATER_SWAP_FACTOR);
    }

    /**
     * Internal: mints the water to the given wallet.
     */
    function _mintWater(address sender, uint256 waterAmount) internal {
        // check: that the total Water supply hasn't been exceeded.
        require(totalSupply() + waterAmount < MAX_WATER_SUPPLY, "OVER MAX SUPPLY");
        _mint(sender, waterAmount);
        emit Minted(sender, waterAmount);
    }

    // ADMIN FUNCTIONS

    /**
     * Admin : mints the water to the given wallet.
     */
    function mintWater(address sender, uint256 amount) external onlyOwner {
        _mintWater(sender, amount);
    }

    /**
     * Admin : used for temporarily multipling how much water is distributed per staked air.
     */
    function updateBoosterMultiplier(uint256 _value) external onlyOwner {
        BOOSTER_MULTIPLIER = _value;
    }

    /**
     * Admin : updates how much water you get per staked air (e.g. 3x).
     */
    function updateFarmingFactor(uint256 _value) external onlyOwner {
        WATER_FARMING_FACTOR = _value;
    }

    /**
     * Admin : updates the multiplier for swapping (burning) air for water (e.g. 12x).
     */
    function updateWaterSwapFactor(uint256 _value) external onlyOwner {
        WATER_SWAP_FACTOR = _value;
    }

    /**
     * Admin : updates the maximum available water supply.
     */
    function updateMaxWaterSupply(uint256 _value) external onlyOwner {
        MAX_WATER_SUPPLY = _value;
    }

    /**
     * Admin : util for working out how many people are staked.
     */
    function totalAirHolder() public view returns (uint256) {
        return _allAirsStakeHolders.length;
    }

    /**
     * Admin : gets the wallet for the the given index. Used for rebalancing.
     */
    function getAirHolderByIndex(uint256 index) internal view returns (address){
        return _allAirsStakeHolders[index];
    }

    /**
     * Admin : Rebalances the pool. Mint to the user's wallet. Only called if changing multiplier.
     */
    function rebalanceStakingPool(uint256 from, uint256 to) external onlyOwner {
        // for each holder of staked Air...
        for (uint256 i = from; i <= to; i++) {
            address holderAddress = getAirHolderByIndex(i);

            // check how much water is claimable...
            uint256 pendingClaim = claimableView(holderAddress);
            AirStake memory air = airStakeHolders[holderAddress];

            // supply Water to the owner's wallet...
            _mint(holderAddress, pendingClaim);
            emit Minted(holderAddress, pendingClaim);

            // pdates user's amount of staked airs to the given value. Resets the "since" timestamp.
            _upsertAirStaking(holderAddress, air.amount);
        }
    }
}