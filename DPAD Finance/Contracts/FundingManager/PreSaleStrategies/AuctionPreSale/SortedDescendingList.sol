//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


library SortedDescendingList {
    using SafeMath for uint;

    struct Item {
        uint16 next;
        uint amount;
        uint score;
    }

    uint16 internal constant GUARD = 0;

    function addNode(Item[] storage items, uint score, uint amount) internal {
        uint16 prev = findSortedIndex(items, score);
        require(_verifyIndex(items, score, prev));
        items.push(Item(items[prev].next, amount, score));
        items[prev].next = uint16(items.length.sub(1));
    }

    function updateNode(Item[] storage items, uint score, uint amount) internal {
        (uint16 current, uint16 oldPrev) = findCurrentAndPrevIndex(items, score);
        require(items[oldPrev].next == current);
        require(items[current].amount == amount);
        score = score.add(items[current].score);
        items[oldPrev].next = items[current].next;
        addNode(items, score, amount);
    }

    function initNodes(Item[] storage items) internal {
        items.push(Item(0, 0, 0));
    }

    function _verifyIndex(Item[] storage items, uint score, uint16 prev) internal view returns (bool) {
        return prev == GUARD || (score <= items[prev].score && score > items[items[prev].next].score);
    }

    function findSortedIndex(Item[] storage items, uint score) internal view returns(uint16) {
        Item memory current = items[GUARD];
        uint16 index = GUARD;
        while(current.next != GUARD && items[current.next].score > score) {
            index = current.next;
            current = items[current.next];
        }

        return index;
    }

    function findCurrentAndPrevIndex(Item[] storage items, uint score) internal view returns (uint16, uint16) {
        Item memory current = items[GUARD];
        uint16 currentIndex = GUARD;
        uint16 prevIndex = GUARD;
        while(current.next != GUARD && current.score != score) {
            prevIndex = currentIndex;
            currentIndex = current.next;
            current = items[current.next];
        }

        return (currentIndex, prevIndex);
    }

    function findIndex(Item[] storage items, uint score) internal view returns (uint) {
        Item memory current = items[GUARD];
        Item memory prev = items[GUARD];
        uint index = 0;

        while(current.next != GUARD ) {
            if (current.score == score) {
                index = prev.next;
                break;
            }
            prev = current;
            current = items[current.next];
        }

        return index;
    }
}
