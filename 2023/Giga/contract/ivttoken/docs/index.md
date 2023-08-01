# Solidity API

## GigaToken

_This is a custom token contract for the "GigaToken". It includes functionalities such as
burnable tokens, token snapshots, access control, pausability and permit features.
The token also adds the ability to increase and decrease unlocked tokens for a specific address.
The increase and decrease of unlocked tokens is controlled by an account with the minter role.
Transfers are only allowed when the contract is not paused and if the sender has enough unlocked tokens._

### SNAPSHOT_ROLE

```solidity
bytes32 SNAPSHOT_ROLE
```

### PAUSER_ROLE

```solidity
bytes32 PAUSER_ROLE
```

### MINTER_ROLE

```solidity
bytes32 MINTER_ROLE
```

### ZERO_ADDRESS

```solidity
address ZERO_ADDRESS
```

### owner

```solidity
address owner
```

### unlockedTokens

```solidity
mapping(address => uint256) unlockedTokens
```

### constructor

```solidity
constructor() public
```

_Sets the values for `name` and `symbol`, initializes the `decimals` with a default value of 18.
Grants the minter, pauser and snapshot roles to the deployer and sets them as owner._

### increaseUnlockedTokens

```solidity
function increaseUnlockedTokens(address _recipient, uint256 _amount) public
```

_Increase the amount of unlocked tokens for a given address.
Can only be called by an account with the minter role._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _recipient | address | The address to increase the unlocked tokens for. |
| _amount | uint256 | The amount of tokens to unlock. |

### decreaseUnlockedTokens

```solidity
function decreaseUnlockedTokens(address _recipient, uint256 _amount) public
```

_Decrease the amount of unlocked tokens for a given address.
Can only be called by an account with the minter role._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _recipient | address | The address to decrease the unlocked tokens for. |
| _amount | uint256 | The amount of tokens to lock. |

### _increaseUnlockedTokens

```solidity
function _increaseUnlockedTokens(address _from, uint256 _amount) internal
```

_Increase the amount of unlocked tokens for a given address.
This is an internal function that is only callable from within this contract._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | address | The address to increase the unlocked tokens for. |
| _amount | uint256 | The amount of tokens to unlock. |

### _decreaseUnlockedTokens

```solidity
function _decreaseUnlockedTokens(address _from, uint256 _amount) internal
```

_Decrease the amount of unlocked tokens for a given address.
This is an internal function that is only callable from within this contract._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | address | The address to decrease the unlocked tokens for. |
| _amount | uint256 | The amount of tokens to lock. |

### _beforeTokenTransfer

```solidity
function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal
```

_Hooks into the token transfer mechanism.
It decreases the sender's unlocked token amount if the transfer is not for minting or burning.
Also checks if the sender has enough unlocked tokens.
The transfer is also paused if the contract is in paused state._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | address | Address sending the tokens. |
| _to | address | Address receiving the tokens. |
| _amount | uint256 | Amount of tokens being transferred. |

### snapshot

```solidity
function snapshot() public
```

_Creates a new snapshot ID.
Can only be called by an account with the snapshot role._

### pause

```solidity
function pause() public
```

_Pauses all token transfers.
Can only be called by an account with the pauser role._

### unpause

```solidity
function unpause() public
```

_Unpauses all token transfers.
Can only be called by an account with the pauser role._

### mint

```solidity
function mint(address _to, uint256 _amount) public
```

_Creates `amount` new tokens and assigns them to `account`, increasing
the total supply.
Can only be called by an account with the minter role._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _to | address | Address to mint the tokens to. |
| _amount | uint256 | Amount of tokens to mint. |

### _doesAddressHasEnoughUnlockedTokensToTransfer

```solidity
function _doesAddressHasEnoughUnlockedTokensToTransfer(address _from, uint256 _amount) internal view returns (bool)
```

_Checks if an address has enough unlocked tokens for a transfer._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | address | Address to check the unlocked token amount from. |
| _amount | uint256 | Amount of tokens the address wants to transfer. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | A boolean indicating if the address has enough unlocked tokens for a transfer. |

### getUnlockedTokens

```solidity
function getUnlockedTokens(address _from) public view returns (uint256)
```

_Returns the amount of unlocked tokens for a specific address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | address | The address to check the unlocked tokens for. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The amount of unlocked tokens. |

## MultiSig

_Implements a multi-signature wallet. Transactions can be executed only when approved by a threshold number of signers._

### NewSigner

```solidity
event NewSigner(address signer)
```

### NewTheshold

```solidity
event NewTheshold(uint256 threshold)
```

### SignerRemoved

```solidity
event SignerRemoved(address signer)
```

### Execution

```solidity
event Execution(address destination, bool success, bytes returndata)
```

### TxnRequest

```solidity
struct TxnRequest {
  address to;
  uint256 value;
  bytes data;
  bytes32 nonce;
}
```

### signers

```solidity
address[] signers
```

### isSigner

```solidity
mapping(address => bool) isSigner
```

### executed

```solidity
mapping(bytes32 => bool) executed
```

### threshold

```solidity
uint256 threshold
```

### constructor

```solidity
constructor(address _secondSigner, address _thirdSigner) public
```

_Contract constructor. Sets the initial signers and threshold._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _secondSigner | address | The address of the second signer. |
| _thirdSigner | address | The address of the third signer. |

### receive

```solidity
receive() external payable
```

_Allows the contract to receive funds._

### typedDataHash

```solidity
function typedDataHash(struct MultiSig.TxnRequest params) public view returns (bytes32)
```

_Returns hash of data to be signed_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| params | struct MultiSig.TxnRequest | The struct containing transaction data |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | Packed hash that is to be signed |

### recoverSigner

```solidity
function recoverSigner(address _to, uint256 _value, bytes _data, bytes userSignature, bytes32 _nonce) public view returns (address)
```

_Utility function to recover a signer given a signature_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _to | address | The to address of the transaction |
| _value | uint256 | Transaction value |
| _data | bytes | Transaction calldata |
| userSignature | bytes | The signature provided by the user |
| _nonce | bytes32 | Transaction nonce |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The address of the signer |

### addAdditionalOwners

```solidity
function addAdditionalOwners(address _signer) public
```

_Adds additional owners to the multisig_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _signer | address | The address to be added to the signers list |

### resign

```solidity
function resign() public
```

_Allows a signer to resign, removing them from the multisig_

### executeTransaction

```solidity
function executeTransaction(bytes[] signatures, address _to, uint256 _value, bytes _data, bytes32 _nonce) public returns (bytes)
```

_Executes a multisig transaction given an array of signatures, and TxnRequest params_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| signatures | bytes[] | The array of signatures from multisig holders |
| _to | address | The address a transaction should be sent to |
| _value | uint256 | The transaction value |
| _data | bytes | The data to be sent with the transaction (e.g: to call a contract function) |
| _nonce | bytes32 | The transaction nonce |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes | The return data from the transaction call |

### changeThreshold

```solidity
function changeThreshold(uint256 _threshold) public
```

_Changes the threshold for the multisig_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _threshold | uint256 | The new threshold |

### getOwnerCount

```solidity
function getOwnerCount() public view returns (uint256)
```

_Returns the current number of signers._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The number of signers |

### getSigners

```solidity
function getSigners() public view returns (address[])
```

_Returns the current list of signers._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address[] | The list of signers |

### verifySigners

```solidity
function verifySigners(bytes[] signatures, bytes32 digest) public view returns (bool)
```

_Verifies if signers are part of the signers' list._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| signatures | bytes[] | The list of signatures to be verified |
| digest | bytes32 | The hash of the transaction data |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | A boolean indicating if all signers are valid |

### onlySigner

```solidity
modifier onlySigner()
```

_Modifier to make a function callable only by a signer._

## Verifier

_This contract is used for recovering the signer of a given message._

### TxnRequest

```solidity
struct TxnRequest {
  bytes32 nonce;
}
```

### constructor

```solidity
constructor() public
```

_Contract constructor
Calls the EIP712 constructor to initialize domain separator._

### receive

```solidity
receive() external payable
```

_Fallback function to accept ether_

### typedDataHash

```solidity
function typedDataHash(struct Verifier.TxnRequest params) public view returns (bytes32)
```

_Returns the hash of the provided transaction request, according to EIP712_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| params | struct Verifier.TxnRequest | The transaction request |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | The hash of the transaction request |

### recoverSigner

```solidity
function recoverSigner(bytes32 _nonce, bytes userSignature) external view returns (address)
```

_Recover signer's address for a given signature_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _nonce | bytes32 | The unique transaction nonce |
| userSignature | bytes | The signature provided by the user |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The address recovered from the signature |

## IGigaToken

### mint

```solidity
function mint(address _to, uint256 _amount) external
```

