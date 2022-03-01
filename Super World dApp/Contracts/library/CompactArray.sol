// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library CompactArray {
    function removeByValue(uint[] storage array, uint value) internal {
        uint index = 0;
        while (index < array.length && array[index] != value) {
            index++;
        }
        if (index == array.length) {
            return;
        }
        for (uint i = index; i < array.length - 1; i++){
            array[i] = array[i + 1];
        }
        delete array[array.length - 1];
        array.pop();
    }
}
