// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

/// @notice Standardize the structure of objects within heap
struct order {
    address sender;
    uint256 shares;
    uint256 price;
    uint256 timestamp;
}

/// @title Basic heap operations to be implemented in both min and max
/// @author Ghulam Haider
interface IHeapBase {
    /// @notice Add new element to the heap and heapify
    /// @param _value is the value to insert into the heap
    function insert(order memory _value) external;

    /// @notice View the complete heap
    /// @dev The return value includes 0-index as well which is MAX(int)
    /// @return _heap is the complete heap in array
    function getHeap() external view returns (order[] memory _heap);

    /// @notice Removes the element at index
    /// @param index is the index of the element to remove from the heap
    function removeAt(uint16 index) external;
}

/// @title Implementation of Min Heap data structure
/// @author Ghulam Haider
interface IMinHeap is IHeapBase {
    /// @notice Remove the minimum element from the heap and re-heapify
    /// @return minimum is the value removed from heap
    function removeMin() external returns (order memory minimum);

    /// @notice View the top element of the heap that is minimum
    /// @return minimum is the minimum order inside the heap
    function getMin() external view returns (order memory minimum);
}

/// @title Implementation of Min Heap data structure
/// @author Ghulam Haider
interface IMaxHeap is IHeapBase {
    /// @notice Remove the maximum element from the heap and re-heapify
    /// @return maximum is the value removed from heap
    function removeMax() external returns (order memory maximum);

    /// @notice View the top element of the heap that is maximum
    /// @return maximum is the maximum order inside the heap
    function getMax() external view returns (order memory maximum);
}
