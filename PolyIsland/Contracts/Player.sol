pragma solidity ^0.8.4;

contract Player {
    // {"bits": "32", "location": [0, 32], "max": "4,294,967,295"}
    function bricks(uint256 _data) external pure returns (uint256) {
        return (_data >> 224) & 0xffffffff;
    }

    function addBricks(uint256 _data, uint256 _value) external pure returns (uint256) {
        _value = ((_data >> 224) & 0xffffffff) + _value;
        require(_value <= 0xffffffff, "bricksAdd_outOfBounds");
        return (_data & 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff) | (_value << 224);
    }

    function subBricks(uint256 _data, uint256 _value) external pure returns (uint256) {
        _value = ((_data >> 224) & 0xffffffff) - _value;
        return (_data & 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff) | (_value << 224);
    }

    // {"bits": "8", "location": [32, 40], "max": "255"}
    function purchasedBricks(uint256 _data) external pure returns (uint256) {
        return (_data >> 216) & 0xff;
    }

    function addPurchasedBricks(uint256 _data, uint256 _value) external pure returns (uint256) {
        _value = ((_data >> 216) & 0xff) + _value;
        _value = _value <= 0xff ? _value : 0xff; // math min;
        return (_data & 0xffffffff00ffffffffffffffffffffffffffffffffffffffffffffffffffffff) | (_value << 216);
    }

    // {"bits": "16", "location": [40, 56], "max": "65,535"}
    function swappedBricks(uint256 _data) external pure returns (uint256) {
        return (_data >> 200) & 0xffff;
    }

    function addSwappedBricks(uint256 _data, uint256 _value) external pure returns (uint256) {
        _value = ((_data >> 200) & 0xffff) + _value;
        _value = _value <= 0xffff ? _value : 0xffff; // math min;
        return (_data & 0xffffffffff0000ffffffffffffffffffffffffffffffffffffffffffffffffff) | (_value << 200);
    }

    // {"bits": "40", "location": [56, 96], "max": "1,099,511,627,775"}
    function coins(uint256 _data) external pure returns (uint256) {
        return (_data >> 160) & 0xffffffffff;
    }

    function addCoins(uint256 _data, uint256 _value) external pure returns (uint256) {
        _value = ((_data >> 160) & 0xffffffffff) + _value;
        require(_value <= 0xffffffffff, "coinsAdd_outOfBounds");
        return (_data & 0xffffffffffffff0000000000ffffffffffffffffffffffffffffffffffffffff) | (_value << 160);
    }

    function subCoins(uint256 _data, uint256 _value) external pure returns (uint256) {
        _value = ((_data >> 160) & 0xffffffffff) - _value;
        return (_data & 0xffffffffffffff0000000000ffffffffffffffffffffffffffffffffffffffff) | (_value << 160);
    }

    // {"bits": "24", "location": [96, 120], "max": "16,777,215"}
    function coinsPerHour(uint256 _data) external pure returns (uint256) {
        return (_data >> 136) & 0xffffff;
    }

    function setCoinsPerHour(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0xffffff, "coinsPerHour_outOfBounds");
        return (_data & 0xffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffff) | (_value << 136);
    }

    // {"bits": "40", "location": [120, 160], "max": "1,099,511,627,775"}
    function uncollectedCoins(uint256 _data) external pure returns (uint256) {
        return (_data >> 96) & 0xffffffffff;
    }

    function setUncollectedCoins(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0xffffffffff, "uncollectedCoins_outOfBounds");
        return (_data & 0xffffffffffffffffffffffffffffff0000000000ffffffffffffffffffffffff) | (_value << 96);
    }

    function addUncollectedCoins(uint256 _data, uint256 _value) external pure returns (uint256) {
        _value = ((_data >> 96) & 0xffffffffff) + _value;
        require(_value <= 0xffffffffff, "uncollectedCoinsAdd_outOfBounds");
        return (_data & 0xffffffffffffffffffffffffffffff0000000000ffffffffffffffffffffffff) | (_value << 96);
    }

    // {"bits": "24", "location": [160, 184], "max": "16,777,215"}
    function collectedCoins(uint256 _data) external pure returns (uint256) {
        return (_data >> 72) & 0xffffff;
    }

    function addCollectedCoins(uint256 _data, uint256 _value) external pure returns (uint256) {
        _value = ((_data >> 72) & 0xffffff) + _value;
        _value = _value <= 0xffffff ? _value : 0xffffff; // math min;
        return (_data & 0xffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffff) | (_value << 72);
    }

    // {"bits": "20", "location": [184, 204], "max": "1,048,575"}
    function coinsHour(uint256 _data) external pure returns (uint256) {
        return (_data >> 52) & 0xfffff;
    }

    function setCoinsHour(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0xfffff, "coinsHour_outOfBounds");
        return (_data & 0xffffffffffffffffffffffffffffffffffffffffffffff00000fffffffffffff) | (_value << 52);
    }

    // {"bits": "24", "location": [204, 228], "max": "16,777,215"}
    function uncollectedAirdrop(uint256 _data) external pure returns (uint256) {
        return (_data >> 28) & 0xffffff;
    }

    function setUncollectedAirdrop(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0xffffff, "uncollectedAirdrop_outOfBounds");
        return (_data & 0xfffffffffffffffffffffffffffffffffffffffffffffffffff000000fffffff) | (_value << 28);
    }

    // {"bits": "16", "location": [228, 244], "max": "65,535"}
    function airdropDay(uint256 _data) external pure returns (uint256) {
        return (_data >> 12) & 0xffff;
    }

    function setAirdropDay(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0xffff, "airdropDay_outOfBounds");
        return (_data & 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000fff) | (_value << 12);
    }

    // {"bits": "2", "location": [244, 246], "max": "3"}
    function pendingStarsProfit(uint256 _data) external pure returns (uint256) {
        return (_data >> 10) & 0x3;
    }

    function setPendingStarsProfit(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0x3, "pendingStarsProfit_outOfBounds");
        return (_data & 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3ff) | (_value << 10);
    }

    // {"bits": "2", "location": [246, 248], "max": "3"}
    function pendingStarsBuild(uint256 _data) external pure returns (uint256) {
        return (_data >> 8) & 0x3;
    }

    function setPendingStarsBuild(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0x3, "pendingStarsBuild_outOfBounds");
        return (_data & 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcff) | (_value << 8);
    }

    // {"bits": "2", "location": [248, 250], "max": "3"}
    function starsCollect(uint256 _data) external pure returns (uint256) {
        return (_data >> 6) & 0x3;
    }

    function setStarsCollect(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0x3, "starsCollect_outOfBounds");
        return (_data & 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3f) | (_value << 6);
    }

    // {"bits": "2", "location": [250, 252], "max": "3"}
    function starsBuild(uint256 _data) external pure returns (uint256) {
        return (_data >> 4) & 0x3;
    }

    function setStarsBuild(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0x3, "starsBuild_outOfBounds");
        return (_data & 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcf) | (_value << 4);
    }

    // {"bits": "2", "location": [252, 254], "max": "3"}
    function starsSwap(uint256 _data) external pure returns (uint256) {
        return (_data >> 2) & 0x3;
    }

    function setStarsSwap(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0x3, "starsSwap_outOfBounds");
        return (_data & 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3) | (_value << 2);
    }

    // {"bits": "2", "location": [254, 256], "max": "3"}
    function starsProfit(uint256 _data) external pure returns (uint256) {
        return (_data >> 0) & 0x3;
    }

    function setStarsProfit(uint256 _data, uint256 _value) external pure returns (uint256) {
        require(_value <= 0x3, "starsProfit_outOfBounds");
        return (_data & 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) | (_value << 0);
    }
}
