// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IHeap.sol";

contract MinHeap is IMinHeap {
    /// @dev Using SafeMath to retain bounds of array index ops
    using SafeMath for uint256;

    /// @dev Dynamic array for heap itself
    order[] public heap;

    /// @notice Use constructor to instantiate Heap at MAX(int)
    constructor() {
        heap.push(order(address(0), 0, 2**256 - 1, 0));
    }

    function insert(order memory _value) public override {
        heap.push(_value);

        uint256 currentIndex = heap.length.sub(1);

        while (
            currentIndex > 1 &&
            heap[currentIndex.div(2)].price > heap[currentIndex].price
        ) {
            order memory _temp = heap[currentIndex.div(2)];
            heap[currentIndex.div(2)] = _value;
            heap[currentIndex] = _temp;

            currentIndex = currentIndex.div(2);
        }
    }

    function removeMin() public override returns (order memory minimum) {
        require(heap.length > 1, "MinHeap: Heap is empty");

        minimum = heap[1];
        heap[1] = heap[heap.length.sub(1)];
        heap.pop();
        uint256 currentIndex = 1;
        //Because the loop below doesn't work when heap.length == 3, had to add this
        if (heap.length == 3) {
            if (heap[currentIndex].price > heap[currentIndex + 1].price) {
                order memory _temp = heap[currentIndex];
                heap[currentIndex] = heap[currentIndex + 1];
                heap[currentIndex + 1] = _temp;
            }
            return minimum;
        }
        while (currentIndex.mul(2) < heap.length.sub(1)) {
            uint256 j = currentIndex.mul(2);
            order memory rightChild = heap[j];
            order memory leftChild = heap[j.add(1)];

            if (leftChild.price < rightChild.price) {
                j = j.add(1);
            }

            if (heap[currentIndex].price < heap[j].price) {
                break;
            }

            order memory _temp = heap[currentIndex];
            heap[currentIndex] = heap[j];
            heap[j] = _temp;

            currentIndex = j;
        }
    }

    function removeAt(uint16 index) external override {
        require(heap.length > 1, "MinHeap: Heap is empty");
        require(index < heap.length, "MinHeap: Index greater than Heap length");

        heap[index] = heap[heap.length.sub(1)];
        heap.pop();
        uint256 currentIndex = 1;
        //Because the loop below doesn't work when heap.length == 3, had to add this
        if (heap.length == 3) {
            if (heap[currentIndex].price > heap[currentIndex + 1].price) {
                order memory _temp = heap[currentIndex];
                heap[currentIndex] = heap[currentIndex + 1];
                heap[currentIndex + 1] = _temp;
            }
        }
        while (currentIndex.mul(2) < heap.length.sub(1)) {
            uint256 j = currentIndex.mul(2);
            order memory rightChild = heap[j];
            order memory leftChild = heap[j.add(1)];

            if (leftChild.price < rightChild.price) {
                j = j.add(1);
            }

            if (heap[currentIndex].price < heap[j].price) {
                break;
            }

            order memory _temp = heap[currentIndex];
            heap[currentIndex] = heap[j];
            heap[j] = _temp;

            currentIndex = j;
        }
    }

    function getHeap() public view override returns (order[] memory _heap) {
        return heap;
    }

    function getMin() public view override returns (order memory minimum) {
        minimum = heap[1];
    }
}

contract MaxHeap is IMaxHeap {
    /// @dev Using SafeMath to retain bounds of array index ops
    using SafeMath for uint256;

    /// @dev Dynamic array for heap itself
    order[] public heap;

    /// @notice Use constructor to instantiate Heap at 0
    constructor() {
        heap.push(order(address(0), 0, 0, 0));
    }

    function insert(order memory _value) public override {
        heap.push(_value);

        uint256 currentIndex = heap.length.sub(1);

        while (
            currentIndex > 1 &&
            heap[currentIndex.div(2)].price < heap[currentIndex].price
        ) {
            order memory _temp = heap[currentIndex.div(2)];
            heap[currentIndex.div(2)] = _value;
            heap[currentIndex] = _temp;

            currentIndex = currentIndex.div(2);
        }
    }

    function removeMax() public override returns (order memory maximum) {
        require(heap.length > 1, "MaxHeap: Heap is empty");

        maximum = heap[1];
        heap[1] = heap[heap.length.sub(1)];
        heap.pop();
        uint256 currentIndex = 1;
        //Because the loop below doesn't work when heap.length == 3, had to add this
        if (heap.length == 3) {
            if (heap[currentIndex].price < heap[currentIndex + 1].price) {
                order memory _temp = heap[currentIndex];
                heap[currentIndex] = heap[currentIndex + 1];
                heap[currentIndex + 1] = _temp;
            }
            return maximum;
        }
        while (currentIndex.mul(2) < heap.length.sub(1)) {
            uint256 j = currentIndex.mul(2);
            order memory leftChild = heap[j];
            order memory rightChild = heap[j.add(1)];

            if (leftChild.price < rightChild.price) {
                j = j.add(1);
            }

            if (heap[currentIndex].price > heap[j].price) {
                break;
            }

            order memory _temp = heap[currentIndex];
            heap[currentIndex] = heap[j];
            heap[j] = _temp;

            currentIndex = j;
        }
    }

    function removeAt(uint16 index) external override {
        require(heap.length > 1, "MaxHeap: Heap is empty");
        require(index < heap.length, "MinHeap: Index greater than Heap length");

        heap[index] = heap[heap.length.sub(1)];
        heap.pop();
        uint256 currentIndex = 1;
        //Because the loop below doesn't work when heap.length == 3, had to add this
        if (heap.length == 3) {
            if (heap[currentIndex].price < heap[currentIndex + 1].price) {
                order memory _temp = heap[currentIndex];
                heap[currentIndex] = heap[currentIndex + 1];
                heap[currentIndex + 1] = _temp;
            }
        }
        while (currentIndex.mul(2) < heap.length.sub(1)) {
            uint256 j = currentIndex.mul(2);
            order memory leftChild = heap[j];
            order memory rightChild = heap[j.add(1)];

            if (leftChild.price < rightChild.price) {
                j = j.add(1);
            }

            if (heap[currentIndex].price > heap[j].price) {
                break;
            }

            order memory _temp = heap[currentIndex];
            heap[currentIndex] = heap[j];
            heap[j] = _temp;

            currentIndex = j;
        }
    }

    function getHeap() public view override returns (order[] memory _heap) {
        return heap;
    }

    function getMax() public view override returns (order memory maximum) {
        maximum = heap[1];
    }
}
