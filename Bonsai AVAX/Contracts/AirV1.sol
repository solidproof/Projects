//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "./Authorizable.sol";
import "./BonsaiV1.sol";
// import "hardhat/console.sol";

contract AirV1 is ERC20, Authorizable {
    using SafeMath for uint256;
    string private TOKEN_NAME = "air";
    string private TOKEN_SYMBOL = "AIR";

    address public BONSAI_CONTRACT;

    // the base number of $AIR per bonsai (i.e. 0.75 $air)
    uint256 public BASE_HOLDER_AIR = 750000000000000000;

    // the number of $AIR per bonsai per day per cm (i.e. 0.25 $air /bonsai /day /cm)
    uint256 public AIR_PER_DAY_PER_CM = 250000000000000000;

    // how much air it costs to skip the cooldown
    uint256 public COOLDOWN_BASE = 100000000000000000000; // base 100
    // how much additional air it costs to skip the cooldown per cm
    uint256 public COOLDOWN_BASE_FACTOR = 100000000000000000000; // additional 100 per cm
    // how long to wait before skip cooldown can be re-invoked
    uint256 public COOLDOWN_CD_IN_SECS = 86400; // additional 100 per cm

    uint256 public LEVELING_BASE = 25;
    uint256 public LEVELING_RATE = 2;
    uint256 public COOLDOWN_RATE = 3600; // 60 mins

    // uint8 (0 - 255)
    // uint16 (0 - 65535)
    // uint24 (0 - 16,777,216)
    // uint32 (0 - 4,294,967,295)
    // uint40 (0 - 1,099,511,627,776)
    // unit48 (0 - 281,474,976,710,656)
    // uint256 (0 - 1.157920892e77)

    /**
     * Stores staked bonsai fields (=> 152 <= stored in order of size for optimal packing!)
     */
    struct StakedBonsaiObj {
        // the current cm level (0 -> 16,777,216)
        uint24 cm;
        // when to calculate air from (max 20/02/36812, 11:36:16)
        uint32 sinceTs;
        // for the skipCooldown's cooldown (max 20/02/36812, 11:36:16)
        uint32 lastSkippedTs;
        // how much this bonsai has been watered (in whole numbers)
        uint48 eatenAmount;
        // cooldown time until level up is allow (per cm)
        uint32 cooldownTs;
    }

    // redundant struct - can't be packed? (max totalCm = 167,772,160,000)
    uint40 public totalCm;
    uint16 public totalStakedBonsai;

    StakedBonsaiObj[100001] public stakedBonsai;

    // Events

    event Minted(address owner, uint256 airsAmt);
    event Burned(address owner, uint256 airsAmt);
    event Staked(uint256 tid, uint256 ts);
    event UnStaked(uint256 tid, uint256 ts);

    // Constructor

    constructor(address _bonsaiContract) ERC20(TOKEN_NAME, TOKEN_SYMBOL) {
        BONSAI_CONTRACT = _bonsaiContract;
    }

    // "READ" Functions
    // How much is required to be watered to level up per cm

    function waterLevelingRate(uint256 cm) public view returns (uint256) {
        // need to divide the cm by 100, and make sure the water level is at 18 decimals
        return LEVELING_BASE * ((cm / 100)**LEVELING_RATE);
    }

    // when using the value, need to add the current block timestamp as well
    function cooldownRate(uint256 cm) public view returns (uint256) {
        // need to divide the cm by 100

        return (cm / 100) * COOLDOWN_RATE;
    }

    // Staking Functions

    // stake bonsai, check if is already staked, get all detail for bonsai such as
    function _stake(uint256 tid) internal {
        BonsaiV1 x = BonsaiV1(BONSAI_CONTRACT);

        // verify user is the owner of the bonsai...
        require(x.ownerOf(tid) == msg.sender, "NOT OWNER");

        // get calc'd values...
        (, , , , , , , uint256 cm) = x.allBonsai(tid);
        // if lastSkippedTs is 0 its mean it never have a last skip timestamp
        StakedBonsaiObj memory c = stakedBonsai[tid];
        uint32 ts = uint32(block.timestamp);
        if (stakedBonsai[tid].cm == 0) {
            // create staked bonsai...
            stakedBonsai[tid] = StakedBonsaiObj(
                uint24(cm),
                ts,
                c.lastSkippedTs > 0 ? c.lastSkippedTs :  uint32(ts - COOLDOWN_CD_IN_SECS),
                uint48(0),
                uint32(ts) + uint32(cooldownRate(cm))
            );

            // update snapshot values...
            // N.B. could be optimised for multi-stakes - but only saves 0.5c AUD per bonsai - not worth it, this is a one time operation.
            totalStakedBonsai += 1;
            totalCm += uint24(cm);

            // let ppl know!
            emit Staked(tid, block.timestamp);
        }
    }

    // function staking(uint256 tokenId) external {
    //     _stake(tokenId);
    // }

    function stake(uint256[] calldata tids) external {
        for (uint256 i = 0; i < tids.length; i++) {
            _stake(tids[i]);
        }
    }

    /**
     * Calculates the amount of air that is claimable from a bonsai.
     */
    function claimableView(uint256 tokenId) public view returns (uint256) {
        StakedBonsaiObj memory c = stakedBonsai[tokenId];
        if (c.cm > 0) {
            uint256 airPerDay = ((AIR_PER_DAY_PER_CM * (c.cm / 100)) +
                BASE_HOLDER_AIR);
            uint256 deltaSeconds = block.timestamp - c.sinceTs;
            return deltaSeconds * (airPerDay / 86400);
        } else {
            return 0;
        }
    }

    // Removed "getBonsai" to save space

    // struct BonsaiObj {
    //     uint256 cm;
    //     uint256 sinceTs;
    //     uint256 lastSkippedTs;
    //     uint256 eatenAmount;
    //     uint256 cooldownTs;
    //     uint256 requireFeedAmount;
    // }

    // function getBonsai(uint256 tokenId) public view returns (BonsaiObj memory) {
    //     StakedBonsaiObj memory c = stakedBonsai[tokenId];
    //     return
    //         BonsaiObj(
    //             c.cm,
    //             c.sinceTs,
    //             c.lastSkippedTs,
    //             c.eatenAmount,
    //             c.cooldownTs,
    //             waterLevelingRate(c.cm)
    //         );
    // }

    /**
     * Get all MY staked bonsai id
     */

    function myStakedBonsai() public view returns (uint256[] memory) {
        BonsaiV1 x = BonsaiV1(BONSAI_CONTRACT);
        uint256 bonsaiCount = x.balanceOf(msg.sender);
        uint256[] memory tokenIds = new uint256[](bonsaiCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < bonsaiCount; i++) {
            uint256 tokenId = x.tokenOfOwnerByIndex(msg.sender, i);
            StakedBonsaiObj memory bonsai = stakedBonsai[tokenId];
            if (bonsai.cm > 0) {
                tokenIds[counter] = tokenId;
                counter++;
            }
        }
        return tokenIds;
    }

    /**
     * Calculates the TOTAL amount of air that is claimable from ALL bonsais.
     */
    function myClaimableView() public view returns (uint256) {
        BonsaiV1 x = BonsaiV1(BONSAI_CONTRACT);
        uint256 cnt = x.balanceOf(msg.sender);
        require(cnt > 0, "NO BONSAI");
        uint256 totalClaimable = 0;
        for (uint256 i = 0; i < cnt; i++) {
            uint256 tokenId = x.tokenOfOwnerByIndex(msg.sender, i);
            StakedBonsaiObj memory bonsai = stakedBonsai[tokenId];
            // make sure that the token is staked
            if (bonsai.cm > 0) {
                uint256 claimable = claimableView(tokenId);
                if (claimable > 0) {
                    totalClaimable = totalClaimable + claimable;
                }
            }
        }
        return totalClaimable;
    }

    /**
     * Claims air from the provided bonsais.
     */
    function _claimAir(uint256[] calldata tokenIds) internal {
        BonsaiV1 x = BonsaiV1(BONSAI_CONTRACT);
        uint256 totalClaimableAir = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(x.ownerOf(tokenIds[i]) == msg.sender, "NOT OWNER");
            StakedBonsaiObj memory bonsai = stakedBonsai[tokenIds[i]];
            // we only care about bonsai that have been staked (i.e. cm > 0) ...
            if (bonsai.cm > 0) {
                uint256 claimableAir = claimableView(tokenIds[i]);
                if (claimableAir > 0) {
                    totalClaimableAir = totalClaimableAir + claimableAir;
                    // reset since, for the next calc...
                    bonsai.sinceTs = uint32(block.timestamp);
                    stakedBonsai[tokenIds[i]] = bonsai;
                }
            }
        }
        if (totalClaimableAir > 0) {
            _mint(msg.sender, totalClaimableAir);
            emit Minted(msg.sender, totalClaimableAir);
        }
    }

    /**
     * Claims air from the provided bonsais.
     */
    function claimAir(uint256[] calldata tokenIds) external {
        _claimAir(tokenIds);
    }

    /**
     * Unstakes a bonsai. Why you'd call this, I have no idea.
     */
    function _unstake(uint256 tokenId) internal {
        BonsaiV1 x = BonsaiV1(BONSAI_CONTRACT);

        // verify user is the owner of the bonsai...
        require(x.ownerOf(tokenId) == msg.sender, "NOT OWNER");

        // update bonsai...
        StakedBonsaiObj memory c = stakedBonsai[tokenId];
        if (c.cm > 0) {
            // update snapshot values...
            totalCm -= uint24(c.cm);
            totalStakedBonsai -= 1;

            c.cm = 0;
            stakedBonsai[tokenId] = c;

            // let ppl know!
            emit UnStaked(tokenId, block.timestamp);
        }
    }

    function _unstakeMultiple(uint256[] calldata tids) internal {
        for (uint256 i = 0; i < tids.length; i++) {
            _unstake(tids[i]);
        }
    }

    /**
     * Unstakes MULTIPLE bonsai. Why you'd call this, I have no idea.
     */
    function unstake(uint256[] calldata tids) external {
        _unstakeMultiple(tids);
    }

    /**
     * Unstakes MULTIPLE bonsai AND claims the air.
     */
    function withdrawAllBonsaiAndClaim(uint256[] calldata tids) external {
        _claimAir(tids);
        _unstakeMultiple(tids);
    }

    /**
     * Public : update the bonsai's CM level.
     */
     function levelUpBonsai(uint256 tid) external {
        StakedBonsaiObj memory c = stakedBonsai[tid];
        require(c.cm > 0, "NOT STAKED");

        BonsaiV1 x = BonsaiV1(BONSAI_CONTRACT);
        // NOTE Does it matter if sender is not owner?
        // require(x.ownerOf(bonsaiId) == msg.sender, "NOT OWNER");

        // check: bonsai has eaten enough...
        require(c.eatenAmount >= waterLevelingRate(c.cm), "MORE FOOD REQD");
        // check: cooldown has passed...
        require(block.timestamp >= c.cooldownTs, "COOLDOWN NOT MET");

        // increase cm, reset eaten to 0, update next water level and cooldown time
        c.cm = c.cm + 100;
        c.eatenAmount = 0;
        c.cooldownTs = uint32(block.timestamp + cooldownRate(c.cm));
        stakedBonsai[tid] = c;

        // need to increase overall size
        totalCm += uint24(100);

        // and update the bonsai contract
        x.setCm(tid, c.cm);
    }

    /**
     * Internal: burns the given amount of air from the wallet.
     */
    function _burnAir(address sender, uint256 airAmount) internal {
        // NOTE do we need to check this before burn?
        require(balanceOf(sender) >= airAmount, "NOT ENOUGH AIR");
        _burn(sender, airAmount);
        emit Burned(sender, airAmount);
    }

    /**
     * Burns the given amount of air from the sender's wallet.
     */
    function burnAir(address sender, uint256 airAmount) external onlyAuthorized {
        _burnAir(sender, airAmount);
    }

    /**
     * Skips the "levelUp" cooling down period, in return for burning Oxygen.
     */
     function skipCoolingOff(uint256 tokenId, uint256 airAmt) external {
        StakedBonsaiObj memory bonsai = stakedBonsai[tokenId];
        require(bonsai.cm != 0, "NOT STAKED");

        uint32 ts = uint32(block.timestamp);

        // NOTE Does it matter if sender is not owner?
        // BonsaiV1 instance = BonsaiV1(BONSAI_CONTRACT);
        // require(instance.ownerOf(bonsaiId) == msg.sender, "NOT OWNER");

        // check: enough air in wallet to pay
        uint256 walletBalance = balanceOf(msg.sender);
        require( walletBalance >= airAmt, "NOT ENOUGH AIR IN WALLET");

        // check: provided air amount is enough to skip this level
        require(airAmt >= checkSkipCoolingOffAmt(bonsai.cm), "NOT ENOUGH AIR TO SKIP");

        // check: user hasn't skipped cooldown in last 24 hrs
        require((bonsai.lastSkippedTs + COOLDOWN_CD_IN_SECS) <= ts, "BLOCKED BY 24HR COOLDOWN");

        // burn air
        _burnAir(msg.sender, airAmt);

        // disable cooldown
        bonsai.cooldownTs = ts;
        // track last time cooldown was skipped (i.e. now)
        bonsai.lastSkippedTs = ts;
        stakedBonsai[tokenId] = bonsai;
    }

    /**
     * Calculates the cost of skipping cooldown.
     */
    function checkSkipCoolingOffAmt(uint256 cm) public view returns (uint256) {
        // NOTE cannot assert CM is < 100... we can have large numbers!
        return ((cm / 100) * COOLDOWN_BASE_FACTOR);
    }

    /**
     * Amt water Watering the bonsai
     */
    function waterBonsai(uint256 tokenId, uint256 waterAmount)
        external
        onlyAuthorized
    {
        StakedBonsaiObj memory bonsai = stakedBonsai[tokenId];
        require(bonsai.cm > 0, "NOT STAKED");
        require(waterAmount > 0, "NOTHING TO FEED");
        // update the block time as well as claimable
        bonsai.eatenAmount = uint48(waterAmount / 1e18) + bonsai.eatenAmount;
        stakedBonsai[tokenId] = bonsai;
    }

    // NOTE What happens if we update the multiplier, and people have been staked for a year...?
    // We need to snapshot somehow... but we're physically unable to update 10k records!!!

    // Removed "updateBaseWater" - to make space

    // Removed "updateWaterPerDayPerCm" - to make space

    // ADMIN: to update the cost of skipping cooldown
    function updateSkipCooldownValues(
        uint256 a,
        uint256 b,
        uint256 c,
        uint256 d,
        uint256 e
    ) external onlyOwner {
        COOLDOWN_BASE = a;
        COOLDOWN_BASE_FACTOR = b;
        COOLDOWN_CD_IN_SECS = c;
        BASE_HOLDER_AIR = d;
        AIR_PER_DAY_PER_CM = e;
    }

    // INTRA-CONTRACT: use this function to mint air to users
    // this also get called by the FEED contract
    function mintAir(address sender, uint256 amount) external onlyAuthorized {
        _mint(sender, amount);
        emit Minted(sender, amount);
    }

    // ADMIN: drop air to the given bonsai wallet owners (within the bonsaiId range from->to).
    function airdropToExistingHolder(
        uint256 from,
        uint256 to,
        uint256 amountOfOxygen
    ) external onlyOwner {
        // mint 100 air to every owners
        BonsaiV1 instance = BonsaiV1(BONSAI_CONTRACT);
        for (uint256 i = from; i <= to; i++) {
            address currentOwner = instance.ownerOf(i);
            if (currentOwner != address(0)) {
                _mint(currentOwner, amountOfOxygen * 1e18);
            }
        }
    }

    // ADMIN: Rebalance user wallet by minting air (within the bonsaiId range from->to).
    // NOTE: This is use when we need to update air production
    function rebalanceWaterClaimableToUserWallet(uint256 from, uint256 to)
        external
        onlyOwner
    {
        BonsaiV1 instance = BonsaiV1(BONSAI_CONTRACT);
        for (uint256 i = from; i <= to; i++) {
            address currentOwner = instance.ownerOf(i);
            StakedBonsaiObj memory bonsai = stakedBonsai[i];
            // we only care about bonsai that have been staked (i.e. cm > 0) ...
            if (bonsai.cm > 0) {
                _mint(currentOwner, claimableView(i));
                bonsai.sinceTs = uint32(block.timestamp);
                stakedBonsai[i] = bonsai;
            }
        }
    }
}