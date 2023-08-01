# Connectivty Tokens Contract
[![Test](https://github.com/investtools/ivttoken/actions/workflows/test.yml/badge.svg)](https://github.com/investtools/ivttoken/actions/workflows/test.yml) [![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)



This is the main Connectivity Token's smart contract development repository.
Copyright (C) 2023  Marco Jardim

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

## Vision Statement
Our vision is to provide reliable and affordable internet connectivity to schools in hard-to-reach areas, enabling children and their families to access education and technology, and empowering them to improve their lives.

## Mission Statement
Our mission is to leverage innovative technologies, partnerships, and incentives to ensure that schools in remote areas have access to fast and reliable internet connectivity. We aim to promote transparency, trust, and accountability in the delivery of these services, and to foster a sense of ownership and engagement among all stakeholders.

## Community Statement
We are committed to working closely with the local communities in which we operate to understand their needs and to ensure that our services are tailored to meet their specific requirements. We will engage in open and transparent communication with all stakeholders, including schools, ISPs, government agencies, and incentive providers, to build trust, foster collaboration, and maximize the impact of our project.

## Licensing Strategy
This project will adopt the [Affero General Public License version 3 (AGPLv3)](LICENSE.md) as its primary open-source license. This decision is based on the project's commitment to fostering collaboration, promoting transparency, and ensuring that any modifications or derivative works contribute back to the open-source community. By using AGPLv3, the project ensures that users can freely access, modify, and distribute the software while also maintaining the obligation to release their modifications or derivative works under the same license.

In addition to the AGPLv3, the project may consider offering a dual licensing model, providing users the option to choose between the open-source AGPLv3 license and a commercial license. This approach can cater to those who require more flexibility, such as the ability to use the software in proprietary projects or access to premium support.

By adopting the AGPLv3 and potentially implementing a dual licensing model, the School Connectivity Initiative aims to create a sustainable and collaborative ecosystem that encourages the sharing of knowledge, resources, and expertise while also allowing for diverse monetization opportunities.

## Key Trademarks
TBD

## Code of Conduct
We are committed to fostering a welcoming and inclusive community. Please read our [Code of Conduct](CODE_OF_CONDUCT.md) for more information.

## Features

- ERC20 compliant
- Burnable tokens
- Snapshots
- Pausable
- Permit functionality
- Access control

## Dependencies

- OpenZeppelin Contracts: a library of secure and tested smart contracts for the Ethereum network.
- Hardhat: a development environment for Ethereum smart contracts.

## 🔧 Setting up local development

### Requirements

- [Node v16](https://nodejs.org/download/release/latest-v16.x/)  
- [Git](https://git-scm.com/downloads)

### Local Setup Steps

#### Clone the repository
```sh
git clone https://github.com/investtools/ivttoken.git
```

#### Install dependencies
```sh
npm install
```

#### Set up environment variables (keys)
```sh
cp .env.example .env # (linux)
copy .env.example .env # (windows)
```

### Hardhat usage:
#### Just Compile: 
```sh
npx hardhat compile
```

## Deploy locally: 
#### Dry deployment: 
```sh
npx hardhat deploy
```

#### With node running:
```sh
npx hardhat node
```

#### Connect with console:
```sh
npx hardhat console --network localhost
```

#### Compile and Deploy to Mumbai Testnet:
```sh
npx hardhat deploy --network polygonMumbai
```
## Test: 
```sh
npx hardhat test
```

## Generate typescript files
```sh
npx hardhat typechain
```

## Clean artifacts (doesn't need to be versioned):
```sh
npx hardhat clean
```

### Notes for `localhost`
-   The `deployments/localhost` directory is included in the git repository,
    so that the contract addresses remain constant. Otherwise, the frontend's
    `constants.ts` file would need to be updated.
-   Avoid committing changes to the `deployments/localhost` files (unless you
    are sure), as this will alter the state of the hardhat node when deployed
    in tests.

## Contract Functions

### Roles

- `DEFAULT_ADMIN_ROLE`: assigned to the contract deployer, this role can grant and revoke other roles.
- `SNAPSHOT_ROLE`: can create snapshots.
- `PAUSER_ROLE`: can pause and unpause the contract.
- `MINTER_ROLE`: can mint tokens and manage unlocked tokens.

### Token Management

- `mint(address _to, uint256 _amount)`: mints `_amount` tokens and assigns them to `_to`. Accessible by `MINTER_ROLE`.
- `increaseUnlockedTokens(address _recipient, uint _amount)`: increases the number of unlocked tokens for `_recipient` by `_amount`. Accessible by `MINTER_ROLE`.
- `decreaseUnlockedTokens(address _recipient, uint _amount)`: decreases the number of unlocked tokens for `_recipient` by `_amount`. Accessible by `MINTER_ROLE`.

### Pausable

- `pause()`: pauses the contract, blocking transfers, approvals, and mints. Accessible by `PAUSER_ROLE`.
- `unpause()`: unpauses the contract. Accessible by `PAUSER_ROLE`.

### Snapshots

- `snapshot()`: creates a new snapshot of the token balances. Accessible by `SNAPSHOT_ROLE`.

### Utilities

- `verifyAddress(address _signer, string memory _message, bytes memory _signature)`: verifies if a given Ethereum signed message `_signature` was signed by `_signer` for the given `_message`.
- `getMessageHash(string memory _message)`: returns the keccak256 hash of `_message`.
- `getEthSignedMessageHash(bytes32 _messageHash)`: returns the Ethereum signed message hash for `_messageHash`.
- `recover(bytes32 _ethSignedMessageHash, bytes memory _signature)`: recovers the signer's address from the given Ethereum signed message hash `_ethSignedMessageHash` and `_signature`.
- `getUnlockedTokens(address _from)`: returns the number of unlocked tokens for the address `_from`.


## Deployments

### Mainnet
- GigaToken: [0xd8e40ccd8bcb4e5994b79a094f6f39e7a9d1b4aa](https://polygonscan.com/address/0xd8e40ccd8bcb4e5994b79a094f6f39e7a9d1b4aa#code)
- Multisig: [0xe1c9cdb52c9759204fda541976d15b3d6f67b546](https://polygonscan.com/address/0xe1c9cdb52c9759204fda541976d15b3d6f67b546#code)
- Verifier: [0x8f2bec657241eb98a89012ecbe24b13be3ef8db8](https://polygonscan.com/address/0x8f2bec657241eb98a89012ecbe24b13be3ef8db8#code)

### Mumbai Testnet
- GigaToken: [0x8CBC04668981e3f7901D46CB56611611545B7A6D](https://mumbai.polygonscan.com/address/0x8CBC04668981e3f7901D46CB56611611545B7A6D#code)
- Multisig: [0x685a13093cA561F531c93185B942a3f33385e14E](https://mumbai.polygonscan.com/address/0x685a13093cA561F531c93185B942a3f33385e14E#code)
- Verifier: [0xD5E253Ff866a342D4227c71eB90263713A79A04b](https://mumbai.polygonscan.com/address/0xD5E253Ff866a342D4227c71eB90263713A79A04b#code)