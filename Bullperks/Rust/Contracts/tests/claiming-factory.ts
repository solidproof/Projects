import * as anchor from '@project-serum/anchor';
import * as serumCmn from "@project-serum/common";
import * as spl from "@solana/spl-token";
import { LAMPORTS_PER_SOL } from '@solana/web3.js';
import * as assert from 'assert';

import * as merkle from './merkle-tree';
import * as claiming from '../web3/claiming';

import * as ty from '../target/types/claiming_factory';

export async function createMint(provider: anchor.Provider, authority?: anchor.web3.PublicKey) {
  if (authority === undefined) {
    authority = provider.wallet.publicKey;
  }
  const mint = await spl.Token.createMint(
    provider.connection,
    provider.wallet.payer,
    authority,
    null,
    6,
    spl.TOKEN_PROGRAM_ID,
  );
  return mint;
}

describe('claiming-factory', () => {
  const provider = anchor.Provider.env();
  anchor.setProvider(provider);

  const client = new claiming.Client(provider.wallet, claiming.LOCALNET);

  const user = anchor.web3.Keypair.generate();
  const userWallet = new anchor.Wallet(user);
  const userClient = new claiming.Client(userWallet, claiming.LOCALNET);

  const admin = anchor.web3.Keypair.generate();
  const adminWallet = new anchor.Wallet(admin);
  const adminClient = new claiming.Client(adminWallet, claiming.LOCALNET);

  const program = anchor.workspace.ClaimingFactory as anchor.Program<ty.ClaimingFactory>;

  type ClaimingUser = {
    wallet: anchor.Wallet,
    tokenAccount: anchor.web3.PublicKey,
  };

  let
    mint: spl.Token,
    config: anchor.web3.PublicKey,
    merkleData: merkle.MerkleData,
    claimingUsers: ClaimingUser[];

  async function generateMerkle(): Promise<[merkle.MerkleData, ClaimingUser[]]> {
    const data = [];
    const wallets = [];
    for (var i = 0; i < 5; i++) {
      const wallet = new anchor.Wallet(anchor.web3.Keypair.generate());
      data.push({ address: wallet.publicKey, amount: i });
      const tokenAccount = await serumCmn.createTokenAccount(provider, mint.publicKey, wallet.publicKey);

      let tx = await provider.connection.requestAirdrop(wallet.publicKey, 2 * LAMPORTS_PER_SOL);
      await provider.connection.confirmTransaction(tx);

      wallets.push({ wallet, tokenAccount });
    }
    return [merkle.getMerkleProof(data), wallets];
  }

  function mockSchedule(): claiming.Period[] {
    const nowTs = Date.now() / 1000;
    return [
      {
        tokenPercentage: new anchor.BN(100_000_000_000),
        startTs: new anchor.BN(nowTs + 2),
        intervalSec: new anchor.BN(1),
        times: new anchor.BN(1),
        airdropped: false,
      }
    ];
  }

  async function setupDistributor(schedule: claiming.Period[] = mockSchedule()) {
    const distributor = await client.createDistributor(
      mint.publicKey,
      merkleData.root,
      schedule
    );
    const distributorAccount = await program.account.merkleDistributor.fetch(distributor);

    const vault = distributorAccount.vault;
    mint.mintTo(vault, provider.wallet.publicKey, [], 1000);

    const vaultAuthority = await anchor.web3.PublicKey.createProgramAddress(
      [
        distributor.toBytes(),
        [distributorAccount.vaultBump]
      ],
      program.programId
    );

    return {
      distributor,
      distributorAccount,
      vault,
      vaultAuthority,
    };
  }

  async function claim(
    distributor: anchor.web3.PublicKey,
    index: number,
    proof?: merkle.MerkleProof
  ): Promise<[merkle.MerkleProof, ClaimingUser]> {
    const merkleElement = proof ? proof : merkleData.proofs[index];
    const claimingUser = claimingUsers[index];
    const elementClient = new claiming.Client(claimingUser.wallet, claiming.LOCALNET);
    await elementClient.initUserDetails(distributor, merkleElement.address);

    while (true) {
      try {
        console.log(
          "available to claim",
          await elementClient.getAmountAvailableToClaim(
            distributor,
            claimingUser.wallet.publicKey,
            merkleElement.amount.toNumber()
          )
        );

        await elementClient.claim(
          distributor,
          claimingUser.tokenAccount,
          merkleElement.amount,
          merkleElement.proofs
        );
        break;
      } catch (err: any) {
        if (err.code != 6015) {
          throw err;
        }
        await serumCmn.sleep(15000);
      }
    }

    return [merkleElement, claimingUser];
  }

  before(async () => {
    mint = await createMint(provider);
    config = await client.createConfig();
    let tx = await provider.connection.requestAirdrop(user.publicKey, 5 * LAMPORTS_PER_SOL);
    await provider.connection.confirmTransaction(tx);
    tx = await provider.connection.requestAirdrop(admin.publicKey, 5 * LAMPORTS_PER_SOL);
    await provider.connection.confirmTransaction(tx);

    [merkleData, claimingUsers] = await generateMerkle();
  });

  context("admin add/remove", async function () {
    beforeEach(async function () {
      anchor.setProvider(provider);
    });

    it('should not allow to add admin by user', async function () {
      await assert.rejects(
        async () => {
          await userClient.addAdmin(admin.publicKey);
        },
        (err) => {
          assert.equal(err.code, 6005);
          return true;
        }
      );
    });

    it('should add admin by owner', async function () {
      await client.addAdmin(admin.publicKey);

      const configAccount = await program.account.config.fetch(config);
      const [newAdmin] = configAccount.admins.filter((a) => a && a.equals(admin.publicKey));
      assert.ok(newAdmin);
    });

    it('should not allow to remove admin by user', async function () {
      await assert.rejects(
        async () => {
          await userClient.removeAdmin(admin.publicKey);
        },
        (err) => {
          assert.equal(err.code, 6005);
          return true;
        }
      );
    });

    it('should remove admin by owner', async function () {
      await client.removeAdmin(admin.publicKey);

      const configAccount = await program.account.config.fetch(config);
      const maybeNewAdmin = configAccount.admins.filter((a) => a && a.equals(admin.publicKey));
      assert.deepStrictEqual(maybeNewAdmin, []);
    });
  });

  context('create disributor', async function () {
    it("shouldn't allow deploy new distributor if not owner or admin", async function () {
      await assert.rejects(
        async () => {
          await userClient.createDistributor(mint.publicKey, merkleData.root, []);
        },
        (err) => {
          assert.equal(err.code, 6006);
          return true;
        }
      );
    });

    it("should allow to initialize new distributor by admin", async function () {
      await client.addAdmin(admin.publicKey);

      const distributor = await adminClient.createDistributor(
        mint.publicKey,
        merkleData.root,
        mockSchedule()
      );
      await program.account.merkleDistributor.fetch(distributor);
    });

    it("should allow to initialize new distributor by owner", async function () {
      const distributor = await client.createDistributor(
        mint.publicKey,
        merkleData.root,
        mockSchedule()
      );
      await program.account.merkleDistributor.fetch(distributor);
    });
  });

  context('distributor', async function () {
    beforeEach(async function () {
      const r = await setupDistributor();

      this.distributor = r.distributor;
      this.distributorAccount = r.distributorAccount;
      this.vault = r.vault;
      this.vaultAuthority = r.vaultAuthority;
    });

    it('should have correct initial values', async function () {
      assert.ok(this.distributorAccount.merkleIndex.eqn(0));
      assert.ok(Buffer.from(this.distributorAccount.merkleRoot).equals(merkleData.root));
    });

    context("withdraw tokens", async function () {
      it("shouldn't allow withdraw by user", async function () {
        const targetWallet = await serumCmn.createTokenAccount(userClient.provider, mint.publicKey, user.publicKey);

        await assert.rejects(
          async () => {
            await userClient.withdrawTokens(new anchor.BN(100), this.distributor, targetWallet);
          },
          (err) => {
            assert.equal(err.code, 6005);
            return true;
          }
        );
      });

      it("shouldn't allow withdraw by admin", async function () {
        const targetWallet = await serumCmn.createTokenAccount(adminClient.provider, mint.publicKey, admin.publicKey);

        await assert.rejects(
          async () => {
            await adminClient.withdrawTokens(new anchor.BN(100), this.distributor, targetWallet);
          },
          (err) => {
            assert.equal(err.code, 6005);
            return true;
          }
        );
      });

      it("should withdraw token by owner", async function () {
        const targetWallet = await serumCmn.createTokenAccount(provider, mint.publicKey, user.publicKey);
        await client.withdrawTokens(new anchor.BN(100), this.distributor, targetWallet);

        const targetWalletAccount = await serumCmn.getTokenAccount(provider, targetWallet);
        assert.ok(targetWalletAccount.amount.eqn(100));
      });
    });

    context("update root", async function () {
      const UPDATED_ROOT = Buffer.from("5b86ffd388e4e795ed1640ae6a0f710b1f26aba02befcc54e8e23b4f030daaeb", 'hex').toJSON().data;

      it("shouldn't allow update by user", async function () {
        await assert.rejects(
          async () => {
            await userClient.updateRoot(this.distributor, UPDATED_ROOT, false);
          },
          (err) => {
            assert.equal(err.code, 6006);
            return true;
          }
        );
      });

      it("should allow update by admin", async function () {
        await client.addAdmin(admin.publicKey);
        await adminClient.updateRoot(this.distributor, UPDATED_ROOT, false);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.deepStrictEqual(distributorAccount.merkleRoot, UPDATED_ROOT);
      });

      it("should allow update by owner", async function () {
        await client.updateRoot(this.distributor, UPDATED_ROOT, false);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.deepStrictEqual(distributorAccount.merkleRoot, UPDATED_ROOT);
      });
    });

    context("update root and unpause", async function () {
      it("should unpause if it's paused by admin", async function () {
        await client.pause(this.distributor);
        await client.addAdmin(admin.publicKey);
        await adminClient.updateRoot(this.distributor, merkleData.root, true);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, false);
      });

      it("should unpause if it paused by owner", async function () {
        await client.pause(this.distributor);
        await client.updateRoot(this.distributor, merkleData.root, true);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, false);
      });
    });

    context("pause", async function () {
      it("shouldn't allow to pause the program by user", async function () {
        await assert.rejects(
          async () => {
            await userClient.pause(this.distributor);
          },
          (err) => {
            assert.equal(err.code, 6006);
            return true;
          }
        );

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, false);
      });

      it("shouldn't allow to pause the program if it already paused", async function () {
        await client.pause(this.distributor);
        let balanceBefore = await provider.connection.getBalance(provider.wallet.publicKey);

        await assert.rejects(
          async () => {
            await client.pause(this.distributor);
          },
          (err) => {
            assert.equal(err.code, 6007);
            return true;
          }
        );

        let balanceAfter = await provider.connection.getBalance(provider.wallet.publicKey);
        assert.equal(balanceBefore, balanceAfter);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, true);
      });

      it("should allow to pause the program by admin", async function () {
        await client.addAdmin(admin.publicKey);
        await adminClient.pause(this.distributor);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, true);
      });

      it("should allow to pause the program by owner", async function () {
        await client.pause(this.distributor);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, true);
      });
    });

    context("unpause", async function () {
      it("shouldn't allow to unpause the program by user", async function () {
        await assert.rejects(
          async () => {
            await userClient.unpause(this.distributor);
          },
          (err) => {
            assert.ok(err.code, 306);
            return true;
          }
        );

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, false);
      });

      it("shouldn't allow to unpause the program if it already unpaused", async function () {
        let balanceBefore = await provider.connection.getBalance(provider.wallet.publicKey);

        await assert.rejects(
          async () => {
            await client.unpause(this.distributor);
          },
          (err) => {
            assert.equal(err.code, 6007);
            return true;
          }
        );

        let balanceAfter = await provider.connection.getBalance(provider.wallet.publicKey);
        assert.equal(balanceBefore, balanceAfter);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, false);
      });

      it("should allow to unpause the program by admin", async function () {
        await client.pause(this.distributor);
        await client.addAdmin(admin.publicKey);
        await adminClient.unpause(this.distributor);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, false);
      });

      it("should allow to unpause the program by owner", async function () {
        await client.pause(this.distributor);
        await client.unpause(this.distributor);

        const distributorAccount = await program.account.merkleDistributor.fetch(this.distributor);
        assert.equal(distributorAccount.paused, false);
      });
    });

    context("check user details", async function () {
      it("should return null if user details are unknown", async function () {
        assert.equal(await client.getUserDetails(this.distributor, provider.wallet.publicKey), null);
      });

      it("should return zero if reward hasn't been claimed", async function () {
        await client.initUserDetails(this.distributor, provider.wallet.publicKey);
        const userDetails = await client.getUserDetails(this.distributor, provider.wallet.publicKey);
        assert.ok(userDetails.claimedAmount.eqn(0));
      });

      it("should have correct claimed amount if reward has been claimed", async function () {
        while (true) {
          try {
            const [merkleElement, _claimingUser] = await claim(this.distributor, 4);
            const userDetails = await client.getUserDetails(this.distributor, merkleElement.address);
            assert.equal(userDetails.claimedAmount.toNumber(), merkleElement.amount.toNumber());
            break;
          } catch (err: any) {
            assert.equal(err.code, 6015);
            await serumCmn.sleep(4000);
          }
        }
      });
    });

    context("update schedule", async function () {
      it("should fail if changes lead to an empty schedule", async function () {
        await assert.rejects(
          async () => {
            await client.updateSchedule(this.distributor, [
              {
                remove: {
                  index: new anchor.BN(0)
                }
              }
            ]);
          },
          (err) => {
            assert.equal(err.code, 6009);
            return true;
          }
        );
      });

      it("should fail if total percentage is not equal to 100% after update", async function () {
        await assert.rejects(
          async () => {
            await client.updateSchedule(this.distributor, [
              {
                update: {
                  index: new anchor.BN(0),
                  period: {
                    ...this.distributorAccount.vesting.schedule[0],
                    ...{ tokenPercentage: new anchor.BN(11111) },
                  }
                }
              }
            ]);
          },
          (err) => {
            assert.equal(err.code, 6011);
            return true;
          }
        );
      });

      it("should fail if total percentage is not equal to 100% after push/remove", async function () {
        await assert.rejects(
          async () => {
            await client.updateSchedule(this.distributor, [
              {
                push: {
                  period: {
                    ...this.distributorAccount.vesting.schedule[0],
                    ...{ tokenPercentage: new anchor.BN(11111) },
                  }
                }
              },
              {
                remove: {
                  index: new anchor.BN(0),
                }
              }
            ]);
          },
          (err) => {
            assert.equal(err.code, 6011);
            return true;
          }
        );
      });

      it("should fail if total percentage is not equal to 100% after push", async function () {
        await assert.rejects(
          async () => {
            const changes = [
              {
                push: {
                  period: {
                    ...this.distributorAccount.vesting.schedule[0],
                    ...{
                      tokenPercentage: new anchor.BN(11111),
                      startTs: this.distributorAccount.vesting.schedule[0].startTs.addn(10),
                    },
                  }
                }
              },
            ];
            await client.updateSchedule(this.distributor, changes);
          },
          (err) => {
            assert.equal(err.code, 6011);
            return true;
          }
        );
      });

      it("should fail if update messes up intervals after update", async function () {
        await assert.rejects(
          async () => {
            await client.updateSchedule(this.distributor, [
              {
                push: {
                  period: {
                    ...this.distributorAccount.vesting.schedule[0],
                    ...{
                      startTs: this.distributorAccount.vesting.schedule[0].startTs.addn(10),
                    }
                  }
                },
              },
              {
                update: {
                  index: new anchor.BN(0),
                  period: {
                    ...this.distributorAccount.vesting.schedule[0],
                    ...{
                      startTs: this.distributorAccount.vesting.schedule[0].startTs.addn(20),
                    }
                  }
                }
              },
            ]);
          },
          (err) => {
            assert.equal(err.code, 6010);
            return true;
          }
        );
      });

      it("should fail if update messes up intervals after push", async function () {
        await assert.rejects(
          async () => {
            await client.updateSchedule(this.distributor, [
              {
                push: {
                  period: {
                    ...this.distributorAccount.vesting.schedule[0],
                    ...{
                      startTs: this.distributorAccount.vesting.schedule[0].startTs.subn(10),
                    }
                  }
                }
              },
            ]);
          },
          (err) => {
            assert.equal(err.code, 6010);
            return true;
          }
        );
      });
    });

    context("claim", async function () {
      it("should claim correctly", async function () {
        const [merkleElement, claimingUser] = await claim(this.distributor, 3);
        const targetWalletAccount = await serumCmn.getTokenAccount(provider, claimingUser.tokenAccount);
        assert.ok(targetWalletAccount.amount.eq(merkleElement.amount));
      });

      it("shouldn't allow to claim token if claiming has been paused", async function () {
        await client.pause(this.distributor);

        await assert.rejects(
          async () => {
            await claim(this.distributor, 4);
          },
          (err) => {
            assert.equal(err.code, 6008);
            return true;
          }
        );
      });

      it("should fail if merkle proof is not correct", async function () {
        await assert.rejects(
          async () => {
            await claim(this.distributor, 4, {
              ...merkleData.proofs[4],
              ...{ proofs: merkleData.proofs[3].proofs },
            });
          },
          (err) => {
            assert.equal(err.code, 6003);
            return true;
          }
        )
      });

      it("shouldn't claim if reward has been claimed", async function () {
        await claim(this.distributor, 4);

        await assert.rejects(
          async () => {
            await claim(this.distributor, 4);
          },
          (err) => {
            assert.equal(err.code, 6004);
            return true;
          }
        );
      });

      it("should claim correctly twice, if root has been changed", async function () {
        let [merkleElement, claimingUser] = await claim(this.distributor, 2);

        const firstAmount = merkleElement.amount;
        let targetWalletAccount = await serumCmn.getTokenAccount(provider, claimingUser.tokenAccount);
        assert.ok(targetWalletAccount.amount.eq(firstAmount));

        let data = [];
        for (const elem of merkleData.proofs) {
          data.push({ address: elem.address, amount: elem.amount.toNumber() * 2 });
        }
        let updatedMerkleData = merkle.getMerkleProof(data);

        await client.updateRoot(this.distributor, updatedMerkleData.root, true);

        [merkleElement, claimingUser] = await claim(this.distributor, 2, updatedMerkleData.proofs[2]);

        targetWalletAccount = await serumCmn.getTokenAccount(provider, claimingUser.tokenAccount);
        assert.ok(targetWalletAccount.amount.eq(merkleElement.amount.add(firstAmount)));
      });
    });

    context("complicated schedule", async function () {
      it("should claim in two attempts", async function () {
        const r = await setupDistributor([
          {
            tokenPercentage: new anchor.BN(50_000_000_000),
            startTs: new anchor.BN(Date.now() / 1000),
            intervalSec: new anchor.BN(1),
            times: new anchor.BN(1),
            airdropped: false,
          },
          {
            tokenPercentage: new anchor.BN(50_000_000_000),
            startTs: new anchor.BN(Date.now() / 1000 + 16),
            intervalSec: new anchor.BN(1),
            times: new anchor.BN(1),
            airdropped: false,
          }
        ]);

        let targetWalletAccount = await serumCmn.getTokenAccount(provider, claimingUsers[2].tokenAccount);
        const beforeClaimAmount = targetWalletAccount.amount;

        const [merkleElement, claimingUser] = await claim(r.distributor, 2);

        targetWalletAccount = await serumCmn.getTokenAccount(provider, claimingUser.tokenAccount);
        console.log("first attempt", targetWalletAccount.amount.toNumber(), merkleElement.amount.toNumber());
        assert.ok(targetWalletAccount.amount.sub(beforeClaimAmount).eq(merkleElement.amount.divn(2)));

        await claim(r.distributor, 2);

        targetWalletAccount = await serumCmn.getTokenAccount(provider, claimingUser.tokenAccount);
        console.log("second attempt", targetWalletAccount.amount.toNumber());
        assert.ok(targetWalletAccount.amount.sub(beforeClaimAmount).eq(merkleElement.amount));
      });

      it("should claim but skip airdropped section", async function () {
        const r = await setupDistributor([
          {
            tokenPercentage: new anchor.BN(50_000_000_000),
            startTs: new anchor.BN(Date.now() / 1000),
            intervalSec: new anchor.BN(1),
            times: new anchor.BN(1),
            airdropped: true,
          },
          {
            tokenPercentage: new anchor.BN(50_000_000_000),
            startTs: new anchor.BN(Date.now() / 1000 + 3),
            intervalSec: new anchor.BN(1),
            times: new anchor.BN(1),
            airdropped: false,
          }
        ]);

        let targetWalletAccount = await serumCmn.getTokenAccount(provider, claimingUsers[2].tokenAccount);
        const beforeClaimAmount = targetWalletAccount.amount;

        const [merkleElement, claimingUser] = await claim(r.distributor, 2);

        targetWalletAccount = await serumCmn.getTokenAccount(provider, claimingUser.tokenAccount);
        console.log(targetWalletAccount.amount.toNumber(), merkleElement.amount.toNumber());
        assert.ok(targetWalletAccount.amount.sub(beforeClaimAmount).eq(merkleElement.amount.divn(2)));

        await assert.rejects(
          async () => {
            await claim(r.distributor, 2);
          },
          (err) => {
            assert.equal(err.code, 6004);
            return true;
          }
        );
      });
    });
  });
});
