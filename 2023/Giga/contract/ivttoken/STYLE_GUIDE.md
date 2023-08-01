# Solidity Style Guide for Giga Token Project

This document presents coding and style guidelines for contributors to the Giga Token project, written primarily in Solidity. Please follow this guide to maintain consistency across the codebase.

## 1. Layout and Formatting

- **Indentation**: Use 4 spaces for indentation, not tabs.

- **Line Length**: Aim to keep lines to a maximum of 80 characters where possible for readability.

- **Blank Lines**: Use blank lines to separate functions, statements, and expressions to improve code readability.

## 2. Naming Conventions

- **Variables and Functions**: Use mixedCase (camelCase) for function and variable names. 

- **Constants**: Use uppercase with underscores to separate words for constants.

- **Contract/Interface**: Use CapWords (PascalCase) for contract and interface names.

- **Events**: Use CapWords (PascalCase) prefixed by "Log" for event names.

- **Enums**: Use CapWords (PascalCase) for enum names and their members.

## 3. Function Order

Organize functions and variables according to their visibility and place them in the following order:

1. `fallback` function (if exists)
2. External
3. Public
4. Internal
5. Private

Within each section, place constant functions above non-constant functions.

## 4. Use Explicit Visibility

Every function and state variable must have visibility explicitly declared. 

## 5. Error Handling

Use `require` for input validation and `assert` for checking invariants. Both should provide error messages.

## 6. NatSpec Comments

All functions must be accompanied by NatSpec comments. NatSpec, Ethereum's natural language specification format, should be used for all function documentation.

Example:

```solidity
/// @title A simple contract example
/// @author Giga Token Team
contract ExampleContract {
    /// @notice Calculate the square of an unsigned integer
    /// @dev This function does not check for overflows, caller function should handle potential overflows.
    /// @param x unsigned integer to square
    /// @return result the square of x
    function square(uint x) public pure returns (uint result) {
        result = x * x;
    }
}
```

The `@title` tag gives a one-line description of the contract. The `@notice` tag provides a user-centric description of the function. The `@dev` tag is for extra details on what a function does. The `@param` and `@return` tags give information about the parameters and return values, respectively.

The `@author` tag defines the creator or maintainers of the contract. This is typically a list of GitHub usernames or email addresses.

In all your interactions regarding this project, please respect the [Giga Token Code of Conduct](CODE_OF_CONDUCT.md).

Please remember that consistent and well-formed code makes the codebase easier to read and understand, makes future development easier, and reduces the likelihood of bugs.

Happy coding!
