// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library MerkleTree {
    struct Tree {
        address[] data;
        mapping(address => uint256) index;
    }

    function insertData(Tree storage self, address staker, uint256 amount, uint256 shares) internal {
        if (self.index[staker] == 0) {
            self.data.push(staker);
            self.index[staker] = self.data.length;
        }
    }

    function removeData(Tree storage self, address staker, uint256 amount, uint256 shares) internal {
        uint256 stakerIndex = self.index[staker];
        require(stakerIndex != 0, "Staker not found");

        // If staker has no more shares, remove them from the tree
        if (shares == 0) {
            uint256 lastIndex = self.data.length - 1;
            address lastStaker = self.data[lastIndex];

            // Swap the last element with the element to remove
            self.data[stakerIndex - 1] = lastStaker;
            self.index[lastStaker] = stakerIndex;

            // Remove the last element
            self.data.pop();
            delete self.index[staker];
        }
    }

    function addressAt(Tree storage self, uint256 index) internal view returns (address) {
        require(index < self.data.length, "Index out of bounds");
        return self.data[index];
    }

    function length(Tree storage self) internal view returns (uint256) {
        return self.data.length;
    }
}