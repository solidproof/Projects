import * as anchor from '@project-serum/anchor';
import * as serumCmn from "@project-serum/common";
import { TokenInstructions } from '@project-serum/serum';

import * as idl from './claiming_factory.json';
import * as ty from './claiming_factory';

const TOKEN_PROGRAM_ID = TokenInstructions.TOKEN_PROGRAM_ID;

const {
  REACT_APP_CLAIMING_PROGRAM_ID = '',
} = process.env;

type Opts = {
  preflightCommitment: anchor.web3.Commitment,
}
const opts: Opts = {
  preflightCommitment: 'processed'
}

type NetworkName = anchor.web3.Cluster | string;

export const LOCALNET = 'http://127.0.0.1:8899';
export const DEVNET = 'devnet';
export const TESTNET = 'testnet';
export const MAINNET = 'mainnet-beta';

const LOCALNET_PROGRAM_ID = REACT_APP_CLAIMING_PROGRAM_ID;
const DEVNET_PROGRAM_ID = REACT_APP_CLAIMING_PROGRAM_ID;
// TODO: change address to actual testnet program address
const TESTNET_PROGRAM_ID = REACT_APP_CLAIMING_PROGRAM_ID;
// TODO: change address to actual mainnet program address
const MAINNET_PROGRAM_ID = REACT_APP_CLAIMING_PROGRAM_ID;

export type CreateDistributorArgs = {
  mint: anchor.web3.PublicKey,
  merkleRoot: number[],
};

export type Period = {
  tokenPercentage: anchor.BN,
  startTs: anchor.BN,
  intervalSec: anchor.BN,
  times: anchor.BN,
  airdropped: boolean,
};

export type UserDetails = {
  lastClaimedAtTs: anchor.BN,
  claimedAmount: anchor.BN,
  bump: number,
};

const FAILED_TO_FIND_ACCOUNT = "Account does not exist";

export class Client {
  provider: anchor.AnchorProvider;
  serumProvider: serumCmn.Provider;
  networkName: NetworkName;
  program: anchor.Program<ty.ClaimingFactory>;

  constructor(wallet: any, networkName: NetworkName) {
    this.networkName = networkName;
    this.provider = this.getProvider(wallet);
    this.program = this.initProgram();
    this.serumProvider = new serumCmn.Provider(this.provider.connection, this.provider.wallet, opts);
  }

  /**
   * Creates the provider and returns it to the caller
   * @param {anchor.Wallet} wallet - the solana wallet
   * @returns {anchor.Provider} Returns the provider
   */
  getProvider(wallet: anchor.Wallet): anchor.AnchorProvider {
    let network: string = '';
    switch (this.networkName) {
      case DEVNET:
      case TESTNET:
      case MAINNET:
        network = anchor.web3.clusterApiUrl(this.networkName);
        break;
      case LOCALNET:
        network = this.networkName;
    }

    const connection = new anchor.web3.Connection(network, opts.preflightCommitment);
    const provider = new anchor.AnchorProvider(connection, wallet, opts);
    return provider;
  }

  /**
   * Initializes the program using program's idl for every network
   * @returns {anchor.Program} Returns the initialized program
   */
  initProgram(): anchor.Program<ty.ClaimingFactory> {
    switch (this.networkName) {
      case LOCALNET:
        return new anchor.Program(idl as anchor.Idl, LOCALNET_PROGRAM_ID, this.provider) as any;
      case DEVNET:
        return new anchor.Program(idl as anchor.Idl, DEVNET_PROGRAM_ID, this.provider) as any;
      case TESTNET:
        return new anchor.Program(idl as anchor.Idl, TESTNET_PROGRAM_ID, this.provider) as any;
      case MAINNET:
        return new anchor.Program(idl as anchor.Idl, MAINNET_PROGRAM_ID, this.provider) as any;
      default:
        return new anchor.Program(idl as anchor.Idl, DEVNET_PROGRAM_ID, this.provider) as any;
    }
  }

  /**
   * Find a valid program address of config account
   * @returns {Promise<[anchor.web3.PublicKey, number]>} Returns the public key of config and the bump number
   */
  async findConfigAddress(): Promise<[anchor.web3.PublicKey, number]> {
    const [config, bump] = await anchor.web3.PublicKey.findProgramAddress(
      [
        new TextEncoder().encode("config")
      ],
      this.program.programId,
    );
    return [config, bump];
  }

  /**
   * Initializes config
   * @returns {Promise<anchor.web3.PublicKey>} Returns the public key of config
   */
  async createConfig() {
    const [config, bump] = await this.findConfigAddress();

    await this.program.rpc.initializeConfig(
      bump,
      {
        accounts: {
          config,
          owner: this.provider.wallet.publicKey,
          systemProgram: anchor.web3.SystemProgram.programId,
        }
      }
    );

    return config;
  }

  /**
   * Find a program address of vault authority
   * @param {anchor.web3.PublicKey} distributor - public key of distributor
   * @returns {Promise<[anchor.web3.PublicKey, number]>} Returns the public key of vault authority and the bump number
   */
  async findVaultAuthority(distributor: anchor.web3.PublicKey): Promise<[anchor.web3.PublicKey, number]> {
    const [vaultAuthority, vaultBump] = await anchor.web3.PublicKey.findProgramAddress(
      [
        distributor.toBytes()
      ],
      this.program.programId,
    );
    return [vaultAuthority, vaultBump];
  }

  /**
   * Initializes distributor
   * @param {anchor.web3.PublicKey} mint - public key of mint to distibute
   * @param {number[]} merkleRoot
   * @param {Period[]} schedule - token distribution data (amount, time)
   * @returns {Promise<anchor.web3.PublicKey>} Returns the public key of newly created distributor
   */
  async createDistributor(mint: anchor.web3.PublicKey, merkleRoot: number[], schedule: Period[]): Promise<anchor.web3.PublicKey> {
    const distributor = anchor.web3.Keypair.generate();
    const [vaultAuthority, vaultBump] = await this.findVaultAuthority(distributor.publicKey);
    const [config, _bump] = await this.findConfigAddress();

    const vault = anchor.web3.Keypair.generate();
    const createTokenAccountInstrs = await serumCmn.createTokenAccountInstrs(
      this.program.provider as serumCmn.Provider,
      vault.publicKey,
      mint,
      vaultAuthority
    );

    await this.program.rpc.initialize(
      {
        vaultBump,
        merkleRoot,
        schedule,
      },
      {
        accounts: {
          distributor: distributor.publicKey,
          adminOrOwner: this.provider.wallet.publicKey,
          vaultAuthority,
          vault: vault.publicKey,
          config,
          systemProgram: anchor.web3.SystemProgram.programId,
        },
        instructions: createTokenAccountInstrs,
        signers: [vault, distributor]
      }
    );

    return distributor.publicKey;
  }

  /**
   * Adds admin
   * @param {anchor.web3.PublicKey} admin - public key of new admin
   */
  async addAdmin(admin: anchor.web3.PublicKey) {
    const [config, _bump] = await this.findConfigAddress();
    await this.program.rpc.addAdmin(
      {
        accounts: {
          config,
          owner: this.provider.wallet.publicKey,
          admin,
        }
      }
    );
  }

  /**
   * Removes admin
   * @param {anchor.web3.PublicKey} admin - public key of removing admin
   */
  async removeAdmin(admin: anchor.web3.PublicKey) {
    const [config, _bump] = await this.findConfigAddress();
    await this.program.rpc.removeAdmin(
      {
        accounts: {
          config,
          owner: this.provider.wallet.publicKey,
          admin,
        },
      },
    );
  }

  /**
   * Pause distributor
   * @param {anchor.web3.PublicKey} distributor - public key of pausing distributor
   */
  async pause(distributor: anchor.web3.PublicKey) {
    await this.setPaused(distributor, true);
  }

  /**
   * Unpause distributor
   * @param {anchor.web3.PublicKey} distributor - public key of unpausing distributor
   */
  async unpause(distributor: anchor.web3.PublicKey) {
    await this.setPaused(distributor, false);
  }

  /**
   * Pause or unpause distributor (only for admin role)
   * @param {anchor.web3.PublicKey} distributor - public key of pausing/unpausing distributor
   * @param {boolean} paused - new status for pausing
   */
  async setPaused(distributor: anchor.web3.PublicKey, paused: boolean) {
    const [config, _bump] = await this.findConfigAddress();
    await this.program.rpc.setPaused(
      paused,
      {
        accounts: {
          distributor,
          config,
          adminOrOwner: this.provider.wallet.publicKey
        }
      }
    );
  }

  /**
   * Withdraws tokens after claim period on target wallet
   * @param {anchor.BN} amount - amount to withdraw
   * @param {anchor.web3.PublicKey} distributor - public key of distributor, on which tokes were claimed
   * @param {anchor.web3.PublicKey} targetWallet - public key of wallet, on which tokens withdraw
   */
  async withdrawTokens(amount: anchor.BN, distributor: anchor.web3.PublicKey, targetWallet: anchor.web3.PublicKey) {
    const distributorAccount = await this.program.account.merkleDistributor.fetch(distributor);
    const [config, _bump] = await this.findConfigAddress();
    const [vaultAuthority, _vaultBump] = await this.findVaultAuthority(distributor);
    await this.program.rpc.withdrawTokens(
      amount,
      {
        accounts: {
          distributor,
          config,
          owner: this.provider.wallet.publicKey,
          vaultAuthority,
          vault: distributorAccount.vault,
          targetWallet,
          tokenProgram: TOKEN_PROGRAM_ID,
        }
      }
    );
  }

  /**
   * Updates merkle root
   * @param {anchor.web3.PublicKey} distributor - public key of distributor, on which tokes were claimed
   * @param {number[]} merkleRoot - new merkle root to set
   * @param {boolean} unpause (optional) - pause/unpause status
   */
  async updateRoot(distributor: anchor.web3.PublicKey, merkleRoot: number[], unpause?: boolean) {
    const [config, _bump] = await this.findConfigAddress();
    unpause = (unpause === undefined) ? false : unpause;
    await this.program.rpc.updateRoot(
      {
        merkleRoot,
        unpause,
      },
      {
        accounts: {
          distributor,
          config,
          adminOrOwner: this.provider.wallet.publicKey,
          clock: anchor.web3.SYSVAR_CLOCK_PUBKEY,
        }
      }
    );
  }

  /**
   * Updates shedule
   * @param {anchor.web3.PublicKey} distributor - public key of distributor, on which tokes were claimed
   * @param {any[]} changes - new shedule data
   */
  async updateSchedule(distributor: anchor.web3.PublicKey, changes: any[]) {
    const [config, _bump] = await this.findConfigAddress();
    await this.program.rpc.updateSchedule(
      {
        changes
      },
      {
        accounts: {
          distributor,
          config,
          adminOrOwner: this.provider.wallet.publicKey,
          clock: anchor.web3.SYSVAR_CLOCK_PUBKEY,
        }
      }
    );
  }

  /**
   * Finds public key of data about user
   * @param {anchor.web3.PublicKey} distributor - public key of distributor, on which tokes were claimed
   * @param {anchor.web3.PublicKey} user - public key of user, which data is finding
   * @returns {Promise<[anchor.web3.PublicKey, number]>} Returns the public key of user details account and the bump
   */
  async findUserDetailsAddress(
    distributor: anchor.web3.PublicKey,
    user: anchor.web3.PublicKey
  ): Promise<[anchor.web3.PublicKey, number]> {
    const distributorAccount = await this.program.account.merkleDistributor.fetch(distributor);
    const [userDetails, bump] = await anchor.web3.PublicKey.findProgramAddress(
      [
        distributor.toBytes(),
        distributorAccount.merkleIndex.toArray('be', 8),
        user.toBytes(),
      ],
      this.program.programId
    );

    return [userDetails, bump];
  }

  /**
   * Initializes user details
   * @param {anchor.web3.PublicKey} distributor - public key of distributor, on which tokes were claimed
   * @param {anchor.web3.PublicKey} user - public key of user, which data is finding
   * @returns {Promise<anchor.web3.PublicKey>} Returns the public key of user details account
   */
  async initUserDetails(
    distributor: anchor.web3.PublicKey,
    user: anchor.web3.PublicKey
  ): Promise<anchor.web3.PublicKey> {
    const [userDetails, bump] = await this.findUserDetailsAddress(distributor, user);
    const userDetailsAccount = await this.getUserDetails(distributor, user);

    if (userDetailsAccount === null) {
      await this.program.rpc.initUserDetails(
        bump,
        {
          accounts: {
            payer: this.provider.wallet.publicKey,
            user,
            userDetails,
            distributor,
            systemProgram: anchor.web3.SystemProgram.programId,
          }
        }
      );
    }

    return userDetails;
  }

  /**
   * Gets user details data
   * @param {anchor.web3.PublicKey} distributor - public key of distributor, on which tokes were claimed
   * @param {anchor.web3.PublicKey} user - public key of user, which data is finding
   * @returns {Promise<UserDetails | null>} Returns data about user claims (amount, time) or null if err
   */
  async getUserDetails(
    distributor: anchor.web3.PublicKey,
    user: anchor.web3.PublicKey
  ): Promise<UserDetails | null> {
    const [userDetails, _bump] = await this.findUserDetailsAddress(distributor, user);

    try {
      const userDetailsAccount = await this.program.account.userDetails.fetch(userDetails);
      return userDetailsAccount;
    } catch (err: any) {
      const errMessage = `${FAILED_TO_FIND_ACCOUNT} ${userDetails.toString()}`;
      if (err.message === errMessage) {
        return null;
      } else {
        throw err;
      }
    }
  }

  /**
   * Claims amount of tokens
   * @param {anchor.web3.PublicKey} distributor - public key of distributor, on which tokes would be claimed
   * @param {anchor.web3.PublicKey} targetWallet - wallet of user, which will withdraw tokens
   * @param {anchor.BN} amount - amount of tokens to claim
   * @param {number[][]} merkleProof - merkle proof
   */
  async claim(
    distributor: anchor.web3.PublicKey,
    targetWallet: anchor.web3.PublicKey,
    amount: anchor.BN,
    merkleProof: number[][]
  ) {
    const distributorAccount = await this.program.account.merkleDistributor.fetch(distributor);
    const [vaultAuthority, _vaultBump] = await this.findVaultAuthority(distributor);
    const [userDetails, _userDetailsBump] = await this.findUserDetailsAddress(
      distributor,
      this.provider.wallet.publicKey
    );
    await this.program.rpc.claim(
      {
        amount,
        merkleProof
      },
      {
        accounts: {
          distributor,
          user: this.provider.wallet.publicKey,
          userDetails,
          vaultAuthority,
          vault: distributorAccount.vault,
          targetWallet,
          tokenProgram: TOKEN_PROGRAM_ID,
          clock: anchor.web3.SYSVAR_CLOCK_PUBKEY,
        }
      }
    );
  }
}
