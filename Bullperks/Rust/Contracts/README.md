# claiming_contracts_solana
Solana Claiming smart contracts

## Deploy

### Rust Installation

https://www.rust-lang.org/tools/install

### Solana Installation

https://docs.solana.com/cli/install-solana-cli-tools

### Anchor Installation

https://project-serum.github.io/anchor/getting-started/installation.html#install-yarn

### Run tests

```bash
anchor build
anchor test
```

### Deploy program

```bash
anchor deploy
anchor deploy --provider.cluster devnet # if you want to deploy on devnet
```

### Initialize config

```bash
# 8kYykaz22b9r48BWzrLhNcCvCwrtKF5Ggr1Mv6ik4w8C is the address of program already deployed on devnet
# set some other `program-id` if you've deployed another program
cargo run -p admin-cli -- --cluster devnet --program-id 8kYykaz22b9r48BWzrLhNcCvCwrtKF5Ggr1Mv6ik4w8C init-config
# this command allows you to show the default config
cargo run -p admin-cli -- --cluster devnet --program-id 8kYykaz22b9r48BWzrLhNcCvCwrtKF5Ggr1Mv6ik4w8C show-config
```

> Now you have working development environment and deployed and initialized program on devnet.

### Add admin

```bash
cargo run -p admin-cli -- --cluster devnet --program-id 8kYykaz22b9r48BWzrLhNcCvCwrtKF5Ggr1Mv6ik4w8C add-admin --admin <some public key>
```

### Init test merkle tree

```bash
cd tests/
# ANCHOR_PROVIDER_URLS points to devnet
# ANCHOR_WALLET points to your main solana wallet
env ANCHOR_PROVIDER_URL=https://api.devnet.solana.com ANCHOR_WALLET=$HOME/.config/solana/id.json npx ts-node -T ./init-merkle-tree.ts
```

The command will print the following data as the result:

* Mint address -- the command created mint under your control and you can mint the tokens
(this is the test scenario so it's okay to have new mint every time)

* Root -- represented as byte buffer, you should pass this value to `init-distributor` command below.
Example:
```json
{"type":"Buffer","data":[173,37,178,225,82,176,124,231,51,17,228,211,31,161,78,98,113,39,48,137,59,125,31,241,170,176,167,53,40,207,121,206]}
```

After that it will show you every user token account (all of them are yours actually)
with amount of tokens it's assigned, an index, and array of proofs which should be passed
to the program on claim stage.

### Create claiming (distributor)

```bash
cargo run -p admin-cli -- --cluster devnet --program-id 8kYykaz22b9r48BWzrLhNcCvCwrtKF5Ggr1Mv6ik4w8C \
create-claiming \
# paste value from above
--merkle '{"type":"Buffer","data":[173,37,178,225,82,176,124,231,51,17,228,211,31,161,78,98,113,39,48,137,59,125,31,241,170,176,167,53,40,207,121,206]}' \
--mint 5Pxh1LwhdECrng7mSQqc7nenxxtVxNFyqnPFm7gZLQYa
```

This command should print distributor address and tx signature as a result.

### Show distributor internal state

```bash
cargo run -p admin-cli -- --cluster devnet --program-id 8kYykaz22b9r48BWzrLhNcCvCwrtKF5Ggr1Mv6ik4w8C show-claiming --claiming 9cmx7sd8CTQBeyfHao9RtiGcA6obSwgiAzRsqxWcG2xi
```
