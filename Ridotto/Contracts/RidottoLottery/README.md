- [Ridotto Lottery](#ridotto-lottery)
  - [Usage](#usage)
  - [Smart Contract Addresses and Subgraph](#smart-contract-addresses-and-subgraph)
    - [Goerli Testnet](#goerli-testnet)
  - [Contributing](#contributing)
  - [License](#license)
  - [Contact](#contact)

# Ridotto Lottery

This repository contains the code for a lottery Dapp built on the Ethereum blockchain. The Dapp uses GlobalRNG for random number generation and allows users to buy a maximum of 6 tickets per transaction. Each ticket is assigned a 6-digit number, which is matched to the winning number digit by digit from the left to the winning random number from VRF call. Rewards are split based on ticket matches in a particular bracket.

## Usage

1. Deploy the contract and set the operator, treasury, and injector addresses using the `setOperatorAndTreasuryAndInjectorAddresses()` function.

2. Start a lottery by calling the `startLottery()` function with the following parameters:

   - `blockTimeinSecondstoEnd`: the block time in seconds to end the lottery
   - `priceOfticketIntoken`: the price of the ticket in token
   - `discount in %`: the discount percentage offered
   - `rewards distribution Array`: the rewards distribution array, where 1000=10% 2000 = 20% and so on with a sum of 10000=100%
   - `treasury fee`: the treasury fee

3. Buy tickets for users by calling the `buyTicket()` function

4. Close the lottery by calling the `closeLottery()` function

5. Draw the final number by calling the `drawFinalNumber()` function with the following parameters:

   - `id`: the lottery id
   - `autoInject(bool)`: a boolean value indicating whether to automatically inject leftover tokens into the new lottery pool

6. Claim tickets by calling the `claimTickets()` function with the following parameters:
   - `id`: the lottery id
   - `array of ticketIds`: an array of ticket Ids that can be fetched from the `viewUserInfoForLotteryId()` function
   - `array of brackets`: an array of brackets that can be fetched from the functions in `settings.js`

Note: The `startLottery()` and `closeLottery()` functions can be called by anyone for getting a reward incentive

## Smart Contract Addresses and Subgraph

### Goerli Testnet

**RNG Mocked Version**

| Contract Name            | Address                                    |
| ------------------------ | ------------------------------------------ |
| Lottery - Proxy Admin    | 0x24e23cc2C9143bB4dee84cc40FB56Eb959A15892 |
| Lottery - Proxy          | 0x424e9c2a248AbF7fb719d1e90BDD78D052601Bd7 |
| Lottery - Implementation | 0xb4D5DE3aDa381B63ED58A3eB3Cc12da1280c89B8 |

**Note:**

- These addresses are for the mocked version of the RNG smart contract, which is used for testing purposes.
- Used inputs for this version:
  - lotteryTokenAddress: 0x4af9961123588b7581460f307574cf463ef2a3f5
  - incentive: 100
  - keyHash: 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc
  - subID: 1
  - gasLimit:1000000
  - rngAddress:0x9b7EFfFe6F14539c29617396bF795C14bd19228b
  - providerId: 1

**Subgraph**

- Deployed to https://thegraph.com/explorer/subgraph/globalaccount/ridottolotterygoerli
- Available Queries (HTTP): https://api.thegraph.com/subgraphs/name/globalaccount/ridottolotterygoerli

**RNG Non-Mocked Version**

- This version of the RNG smart contract is yet to be deployed

## Contributing

Contributions are what makes the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are

**greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b JIRA-KEY`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/JIRA-KEY`)
5. Open a Pull Request
6. Fill the Pull Request template

## License

The primary license for RidottoLottery is **Ridotto Core License** see [`LICENSE`](./LICENSE).

## Contact

Ridotto - [@ridotto_io](https://twitter.com/ridotto_io) - requests@ridotto.io
