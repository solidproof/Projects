// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**
 * @title Liquidity Book Immutable Clone Library
 * @notice Minimal immutable proxy library.
 * @author Trader Joe
 * @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibClone.sol)
 * @author Minimal proxy by 0age (https://github.com/0age)
 * @author Clones with immutable args by wighawag, zefram.eth, Saw-mon & Natalie
 * (https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args)
 * @dev Minimal proxy:
 * Although the sw0nt pattern saves 5 gas over the erc-1167 pattern during runtime,
 * it is not supported out-of-the-box on Etherscan. Hence, we choose to use the 0age pattern,
 * which saves 4 gas over the erc-1167 pattern during runtime, and has the smallest bytecode.
 * @dev Clones with immutable args (CWIA):
 * The implementation of CWIA here doesn't implements a `receive()` as it is not needed for LB.
 */
library ImmutableClone {
    error DeploymentFailed();
    error PackedDataTooBig();

    // address private constant CONTRACT_DEPLOYER = 

    /**
     * @dev Deploys a deterministic clone of `implementation` using immutable arguments encoded in `data`, with `salt`
     * @param implementation The address of the implementation
     * @param data The encoded immutable arguments
     * @param salt The salt
     */
    function cloneDeterministic(address implementation, bytes memory data, bytes32 salt)
        internal
        returns (address instance)
    {
        assembly {
            // Compute the boundaries of the data and cache the memory slots around it.
            let mBefore2 := mload(sub(data, 0x40))
            let mBefore1 := mload(sub(data, 0x20))
            let dataLength := mload(data)
            let dataEnd := add(add(data, 0x20), dataLength)
            let mAfter1 := mload(dataEnd)

            // +2 bytes for telling how much data there is appended to the call.
            let extraLength := add(dataLength, 2)
            // The `creationSize` is `extraLength + 63`
            // The `runSize` is `creationSize - 10`.

            // if `extraLength` is greater than `0xffca` revert as the `creationSize` would be greater than `0xffff`.
            if gt(extraLength, 0xffca) {
                // Store the function selector of `PackedDataTooBig()`.
                mstore(0x00, 0xc8c78139)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            /**
             * ---------------------------------------------------------------------------------------------------+
             * CREATION (10 bytes)                                                                                |
             * ---------------------------------------------------------------------------------------------------|
             * Opcode     | Mnemonic          | Stack     | Memory                                                |
             * ---------------------------------------------------------------------------------------------------|
             * 61 runSize | PUSH2 runSize     | r         |                                                       |
             * 3d         | RETURNDATASIZE    | 0 r       |                                                       |
             * 81         | DUP2              | r 0 r     |                                                       |
             * 60 offset  | PUSH1 offset      | o r 0 r   |                                                       |
             * 3d         | RETURNDATASIZE    | 0 o r 0 r |                                                       |
             * 39         | CODECOPY          | 0 r       | [0..runSize): runtime code                            |
             * f3         | RETURN            |           | [0..runSize): runtime code                            |
             * ---------------------------------------------------------------------------------------------------|
             * RUNTIME (98 bytes + extraLength)                                                                   |
             * ---------------------------------------------------------------------------------------------------|
             * Opcode   | Mnemonic       | Stack                    | Memory                                      |
             * ---------------------------------------------------------------------------------------------------|
             *                                                                                                    |
             * ::: copy calldata to memory :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 36       | CALLDATASIZE   | cds                      |                                             |
             * 3d       | RETURNDATASIZE | 0 cds                    |                                             |
             * 3d       | RETURNDATASIZE | 0 0 cds                  |                                             |
             * 37       | CALLDATACOPY   |                          | [0..cds): calldata                          |
             *                                                                                                    |
             * ::: keep some values in stack :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d       | RETURNDATASIZE | 0                        | [0..cds): calldata                          |
             * 3d       | RETURNDATASIZE | 0 0                      | [0..cds): calldata                          |
             * 3d       | RETURNDATASIZE | 0 0 0                    | [0..cds): calldata                          |
             * 3d       | RETURNDATASIZE | 0 0 0 0                  | [0..cds): calldata                          |
             * 61 extra | PUSH2 extra    | e 0 0 0 0                | [0..cds): calldata                          |
             *                                                                                                    |
             * ::: copy extra data to memory :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 80       | DUP1           | e e 0 0 0 0              | [0..cds): calldata                          |
             * 60 0x35  | PUSH1 0x35     | 0x35 e e 0 0 0 0         | [0..cds): calldata                          |
             * 36       | CALLDATASIZE   | cds 0x35 e e 0 0 0 0     | [0..cds): calldata                          |
             * 39       | CODECOPY       | e 0 0 0 0                | [0..cds): calldata, [cds..cds+e): extraData |
             *                                                                                                    |
             * ::: delegate call to the implementation contract ::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 36       | CALLDATASIZE   | cds e 0 0 0 0            | [0..cds): calldata, [cds..cds+e): extraData |
             * 01       | ADD            | cds+e 0 0 0 0            | [0..cds): calldata, [cds..cds+e): extraData |
             * 3d       | RETURNDATASIZE | 0 cds+e 0 0 0 0          | [0..cds): calldata, [cds..cds+e): extraData |
             * 73 addr  | PUSH20 addr    | addr 0 cds+e 0 0 0 0     | [0..cds): calldata, [cds..cds+e): extraData |
             * 5a       | GAS            | gas addr 0 cds+e 0 0 0 0 | [0..cds): calldata, [cds..cds+e): extraData |
             * f4       | DELEGATECALL   | success 0 0              | [0..cds): calldata, [cds..cds+e): extraData |
             *                                                                                                    |
             * ::: copy return data to memory ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d       | RETURNDATASIZE | rds success 0 0          | [0..cds): calldata, [cds..cds+e): extraData |
             * 3d       | RETURNDATASIZE | rds rds success 0 0      | [0..cds): calldata, [cds..cds+e): extraData |
             * 93       | SWAP4          | 0 rds success 0 rds      | [0..cds): calldata, [cds..cds+e): extraData |
             * 80       | DUP1           | 0 0 rds success 0 rds    | [0..cds): calldata, [cds..cds+e): extraData |
             * 3e       | RETURNDATACOPY | success 0 rds            | [0..rds): returndata                        |
             *                                                                                                    |
             * 60 0x33  | PUSH1 0x33     | 0x33 success 0 rds       | [0..rds): returndata                        |
             * 57       | JUMPI          | 0 rds                    | [0..rds): returndata                        |
             *                                                                                                    |
             * ::: revert ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * fd       | REVERT         |                          | [0..rds): returndata                        |
             *                                                                                                    |
             * ::: return ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 5b       | JUMPDEST       | 0 rds                    | [0..rds): returndata                        |
             * f3       | RETURN         |                          | [0..rds): returndata                        |
             * ---------------------------------------------------------------------------------------------------+
             */
            // Write the bytecode before the data.
            mstore(data, 0x5af43d3d93803e603357fd5bf3)
            // Write the address of the implementation.
            mstore(sub(data, 0x0d), implementation)
            mstore(
                sub(data, 0x21),
                or(
                    shl(0xd8, add(extraLength, 0x35)),
                    or(shl(0x48, extraLength), 0x6100003d81600a3d39f3363d3d373d3d3d3d610000806035363936013d73)
                )
            )
            mstore(dataEnd, shl(0xf0, extraLength))

            // Create the instance.
            // TODO: "Create2" returns zero address
            instance := create2(0, sub(data, 0x1f), add(extraLength, 0x3f), salt)

            // let success:= call(5000, )

            // If `instance` is zero, revert.
            if iszero(instance) {
                // Store the function selector of `DeploymentFailed()`.
                mstore(0x00, 0x30116425)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Restore the overwritten memory surrounding `data`.
            mstore(dataEnd, mAfter1)
            mstore(data, dataLength)
            mstore(sub(data, 0x20), mBefore1)
            mstore(sub(data, 0x40), mBefore2)
        }
    }

    /**
     * @dev Returns the initialization code hash of the clone of `implementation`
     * using immutable arguments encoded in `data`.
     * Used for mining vanity addresses with create2crunch.
     * @param implementation The address of the implementation contract.
     * @param data The encoded immutable arguments.
     * @return hash The initialization code hash.
     */
    function initCodeHash(address implementation, bytes memory data) internal pure returns (bytes32 hash) {
        assembly {
            // Compute the boundaries of the data and cache the memory slots around it.
            let mBefore2 := mload(sub(data, 0x40))
            let mBefore1 := mload(sub(data, 0x20))
            let dataLength := mload(data)
            let dataEnd := add(add(data, 0x20), dataLength)
            let mAfter1 := mload(dataEnd)

            // +2 bytes for telling how much data there is appended to the call.
            let extraLength := add(dataLength, 2)
            // The `creationSize` is `extraLength + 63`
            // The `runSize` is `creationSize - 10`.

            // if `extraLength` is greater than `0xffca` revert as the `creationSize` would be greater than `0xffff`.
            if gt(extraLength, 0xffca) {
                // Store the function selector of `PackedDataTooBig()`.
                mstore(0x00, 0xc8c78139)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Write the bytecode before the data.
            mstore(data, 0x5af43d3d93803e603357fd5bf3)
            // Write the address of the implementation.
            mstore(sub(data, 0x0d), implementation)
            mstore(
                sub(data, 0x21),
                or(
                    shl(0xd8, add(extraLength, 0x35)),
                    or(shl(0x48, extraLength), 0x6100003d81600a3d39f3363d3d373d3d3d3d610000806035363936013d73)
                )
            )
            mstore(dataEnd, shl(0xf0, extraLength))

            // Create the instance.
            hash := keccak256(sub(data, 0x1f), add(extraLength, 0x3f))

            // Restore the overwritten memory surrounding `data`.
            mstore(dataEnd, mAfter1)
            mstore(data, dataLength)
            mstore(sub(data, 0x20), mBefore1)
            mstore(sub(data, 0x40), mBefore2)
        }
    }

    /**
     * @dev Returns the address of the deterministic clone of
     * `implementation` using immutable arguments encoded in `data`, with `salt`, by `deployer`.
     * @param implementation The address of the implementation.
     * @param data The immutable arguments of the implementation.
     * @param salt The salt used to compute the address.
     * @param deployer The address of the deployer.
     * @return predicted The predicted address.
     */
    function predictDeterministicAddress(address implementation, bytes memory data, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 hash = initCodeHash(implementation, data);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /**
     * @dev Returns the address when a contract with initialization code hash,
     * `hash`, is deployed with `salt`, by `deployer`.
     * @param hash The initialization code hash.
     * @param salt The salt used to compute the address.
     * @param deployer The address of the deployer.
     * @return predicted The predicted address.
     */
    function predictDeterministicAddress(bytes32 hash, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the boundaries of the data and cache the memory slots around it.
            let mBefore := mload(0x35)

            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, hash)
            mstore(0x01, shl(96, deployer))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)

            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x35, mBefore)
        }
    }
}
