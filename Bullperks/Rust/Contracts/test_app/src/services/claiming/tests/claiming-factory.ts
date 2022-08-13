import * as anchor from '@project-serum/anchor';
import * as serumCmn from "@project-serum/common";
import * as spl from '@solana/spl-token';
import {
  LAMPORTS_PER_SOL,
  Signer,
  Connection,
  clusterApiUrl,
  ConfirmOptions,
  Keypair, PublicKey, SystemProgram, Transaction, sendAndConfirmTransaction,
} from '@solana/web3.js';
import nacl from 'tweetnacl';
import * as bip39  from 'bip39';
import { derivePath } from 'ed25519-hd-key';

import * as merkle from './merkle-tree';
import * as claiming from '../index';
import * as ty from '../claiming_factory';

const {
  REACT_APP_OWNER_MNEMONIC,
  REACT_APP_ADMIN_MNEMONIC,
  REACT_APP_USER_MNEMONIC,
  REACT_APP_TOKEN_ADDRESS = '',
} = process.env;

const {
  MintLayout,
  mintTo,
  getAssociatedTokenAddress,
  createInitializeMintInstruction,
  createAssociatedTokenAccountInstruction,
  createMintToInstruction,
  createSetAuthorityInstruction,
  TOKEN_PROGRAM_ID,
} = spl;

console.log({ spl })

type ClaimingUser = {
  wallet: any,
  tokenAccount: anchor.web3.PublicKey,
};

export class ClaimingClientForTest {
  connection: anchor.web3.Connection = new Connection(
    clusterApiUrl('devnet'),
    'confirmed',
  );
  solana: any = (window as any).solana;
  provider: anchor.AnchorProvider;
  client: claiming.Client;
  owner: anchor.web3.Keypair;
  ownerWallet: any; // NodeWallet
  user: anchor.web3.Keypair;
  userWallet: any; // NodeWallet
  userClient: claiming.Client;
  admin: anchor.web3.Keypair;
  adminWallet: any; // NodeWallet
  adminClient: claiming.Client;
  program: anchor.Program<ty.ClaimingFactory>;

  mint: anchor.web3.PublicKey = new PublicKey(REACT_APP_TOKEN_ADDRESS);
  config: anchor.web3.PublicKey;
  merkleData: merkle.MerkleData;
  claimingUsers: ClaimingUser[];

  distributor: anchor.web3.PublicKey;
  distributorAccount: any;
  vault: anchor.web3.PublicKey;
  vaultAuthority: anchor.web3.PublicKey;

  testResults: {
    success: boolean,
    message: string,
  }[];

  constructor() {
    try {

      // this.user = anchor.web3.Keypair.generate();
      // this.userWallet = this.provider.wallet;
      // this.userClient = new claiming.Client(this.userWallet, claiming.LOCALNET);

      // this.admin = anchor.web3.Keypair.generate();
      // this.adminWallet = new anchor.Wallet(this.admin);
      // this.adminClient = new claiming.Client(this.adminWallet, claiming.LOCALNET);

      // this.program = anchor.workspace.ClaimingFactory as anchor.Program<ty.ClaimingFactory>;
      this.init(); // todo: async function. may be, it should be runned manually
    } catch (e) {
      console.error('constructor:', e);
    }
  }

  // getMint = async () => {
  //   try {
  //     console.log('getMint:', { REACT_APP_TOKEN_ADDRESS });
  //     const publicKey = new PublicKey(REACT_APP_TOKEN_ADDRESS);
  //     const tokenAccountInfo: any = await this.connection.getAccountInfo(publicKey);
  //     console.log('getMint:', { tokenAccountInfo });
  //     const rawTokenAccount: any = MintLayout.decode(tokenAccountInfo?.data);
  //     console.log('getMint:', { rawTokenAccount });
  //     const rawTokenAccountMint = rawTokenAccount.mint;
  //     this.mint = rawTokenAccountMint;
  //   } catch (e) {
  //     console.error('getMint:', e);
  //     return null;
  //   }
  // }

  getProvider = async () => {
    try {
      const provider = new anchor.AnchorProvider(this.connection, this.userWallet, 'processed' as ConfirmOptions);
      return provider;
    } catch (e) {
      console.error('getProvider:', e);
      return null;
    }
  }

  getKeypairFromMnemonic = async (mnemonic: string): Promise<anchor.web3.Keypair | undefined> => {
    try {
      const seed = await bip39.mnemonicToSeed(mnemonic);
      console.log('getKeypairFromMnemonic:', { seed });
      const seedBuffer = Buffer.from(seed).toString('hex');
      console.log('getKeypairFromMnemonic:', { seedBuffer });
      const path44Change = `m/44'/501'/0'/0'`;
      const derivedSeed = derivePath(path44Change, seedBuffer).key;
      const secretKey: any = nacl.sign.keyPair.fromSeed(derivedSeed).secretKey;
      console.log('getKeypairFromMnemonic:', { secretKey });
      const result = new Keypair(secretKey);
      console.log('getKeypairFromMnemonic:', { result });
      // const seed = await bip39.mnemonicToSeed(mnemonic);
      // console.log('getKeypairFromMnemonic:', { seed });
      // let seedArray = new Uint8Array(seed.slice(0,32))
      // console.log('getKeypairFromMnemonic:', { seedArray });
      // const result = anchor.web3.Keypair.fromSeed(seedArray);
      // console.log('getKeypairFromMnemonic:', { result });
      return result;
    } catch (e) {
      console.error('getKeypairFromMnemonic:', e);
    }
  }

  setWalletsAndClients = async () => {
    try {
      this.userWallet = this.solana;
      this.ownerWallet = this.solana;
      this.adminWallet = this.solana;

      // this.user = await this.getKeypairFromMnemonic(REACT_APP_USER_MNEMONIC as string) as Keypair;
      // this.userWallet = this.user;
      this.userClient = new claiming.Client(this.userWallet, claiming.DEVNET);

      // this.owner = await this.getKeypairFromMnemonic(REACT_APP_OWNER_MNEMONIC as string) as Keypair;
      // this.ownerWallet = this.owner;
      this.client = new claiming.Client(this.ownerWallet, claiming.DEVNET);

      // this.admin = await this.getKeypairFromMnemonic(REACT_APP_ADMIN_MNEMONIC as string) as Keypair;
      // this.adminWallet = this.admin;
      this.adminClient = new claiming.Client(this.adminWallet, claiming.DEVNET);
    } catch (e) {
      console.error(e);
    }
  }

  async createMint2(provider: anchor.AnchorProvider, authority?: anchor.web3.PublicKey) {
    try {
      if (authority === undefined) authority = provider.wallet.publicKey;
      // const payer = anchor.web3.Keypair.generate(); // todo: check
      // const payer = <Signer>{ publicKey: provider.wallet.publicKey }; // todo: check
      const payer = <Signer>await this.getKeypairFromMnemonic(REACT_APP_OWNER_MNEMONIC as string);
      console.log('createMint:', {
        REACT_APP_OWNER_MNEMONIC,
        provider,
        payer,
        payerPublicKey: payer.publicKey.toString(),
        authority,
      });
      const mint = await spl.createMint(
        provider.connection,
        payer,
        authority,
        null,
        6,
      );
      console.log('createMint:', { mint });
      return mint;
    } catch (e) {
      console.error('createMint:', e);
      return null;
    }
  }

  async createMint(
    mint: Keypair,
    wallet: any,
    supply: number,
    decimals = 9,
  ): Promise<PublicKey | null> {
    try {
      if (!wallet.publicKey) throw new Error('Wallet is not initialized');

      const associatedTokenAddress = await getAssociatedTokenAddress(
        mint.publicKey,
        wallet.publicKey,
        false,
      );

      const createAccountInstruction = SystemProgram.createAccount({
        fromPubkey: wallet.publicKey,
        newAccountPubkey: mint.publicKey,
        space: 82,
        lamports: await this.connection.getMinimumBalanceForRentExemption(82),
        programId: TOKEN_PROGRAM_ID,
      });

      const initializeMintInstruction = createInitializeMintInstruction(
        mint.publicKey,
        decimals,
        wallet.publicKey,
        wallet.publicKey,
      );

      const associatedTokenAccountInstruction = createAssociatedTokenAccountInstruction(
        wallet.publicKey,
        associatedTokenAddress,
        wallet.publicKey,
        mint.publicKey,
      );

      const mintToInstruction = createMintToInstruction(
        mint.publicKey,
        associatedTokenAddress,
        wallet.publicKey,
        supply * (10 ** decimals),
        [],
        TOKEN_PROGRAM_ID
      );

      const setAuthorityInstruction = createSetAuthorityInstruction(
        mint.publicKey,
        wallet.publicKey,
        0,
        wallet.publicKey,
        [],
        TOKEN_PROGRAM_ID,
      );

      const instructions = [
        createAccountInstruction,
        initializeMintInstruction,
        associatedTokenAccountInstruction,
        mintToInstruction,
        setAuthorityInstruction,
      ];

      const tx = new Transaction();
      tx.add(...instructions);
      tx.recentBlockhash =  (await this.connection.getLatestBlockhash("finalized")).blockhash;
      tx.feePayer = wallet.publicKey;
      tx.partialSign(mint);
      console.log('createMint:', { mint, wallet, tx });
      // const transactionSignature = await wallet.adapter.sendTransaction(tx, connection, { signers: [mint] });
      const result = await wallet.signAndSendTransaction(tx);
      console.log('createMint:', { result });
      // await this.connection.confirmTransaction(transactionSignature);
      return result;
    } catch (e) {
      console.error('createMint:', e);
      return null;
    }
  }

  async generateMerkle(wallet: any): Promise<[merkle.MerkleData, ClaimingUser[]]> {
    const data: any = [];
    const wallets: any = [];
    for (var i = 0; i < 5; i++) {
      // const wallet = new anchor.Wallet(anchor.web3.Keypair.generate());
      data.push({ address: wallet.publicKey, amount: i });
      const tokenAccount = await serumCmn.createTokenAccount(
        this.provider as any, this.mint, wallet.publicKey
      );

      let tx = await this.provider.connection.requestAirdrop(wallet.publicKey, 2 * LAMPORTS_PER_SOL);
      await this.provider.connection.confirmTransaction(tx);

      wallets.push({ wallet, tokenAccount });
    }
    return [merkle.getMerkleProof(data), wallets];
  }

  mockSchedule(): claiming.Period[] {
    try {
      const nowTs = Date.now() / 1000;
      return [
        {
          tokenPercentage: new anchor.BN(10000),
          startTs: new anchor.BN(nowTs + 2),
          intervalSec: new anchor.BN(1),
          times: new anchor.BN(1),
          airdropped: false,
        }
      ];
    } catch (e) {
      console.error(e);
      return [];
    }
  }

  async setupDistributor(schedule: claiming.Period[] = this.mockSchedule()) {
    try {
      const distributor = await this.client.createDistributor(
        this.mint,
        this.merkleData.root,
        schedule
      );
      const distributorAccount = await this.program.account.merkleDistributor.fetch(distributor);

      const vault = distributorAccount.vault;
      await mintTo(
        this.connection,
        this.solana,
        this.mint,
        vault,
        this.solana.publicKey,
        1000,
      );

      const vaultAuthority = await anchor.web3.PublicKey.createProgramAddress(
        [
          distributor.toBytes(),
          [distributorAccount.vaultBump] as any
        ],
        this.program.programId
      );

      this.distributor = distributor;
      this.distributorAccount = distributorAccount;
      this.vault = vault;
      this.vaultAuthority = vaultAuthority;
    } catch (e) {
      console.error(e);
    }
  }

  async claim(
    distributor: anchor.web3.PublicKey,
    index: number,
    proof?: merkle.MerkleProof
  ): Promise<[merkle.MerkleProof, ClaimingUser]> {
    const merkleElement = proof ? proof : this.merkleData.proofs[index];
    const claimingUser = this.claimingUsers[index];
    const elementClient = new claiming.Client(claimingUser.wallet, claiming.LOCALNET);
    await elementClient.initUserDetails(distributor, merkleElement.address);

    while (true) {
      try {
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

  async init() {
    try {
      const solana = (window as any).solana;
      await solana.connect();
      console.log('init:');
      await this.setWalletsAndClients();
      console.log('init:');
      this.provider = await this.getProvider() as any;
      console.log('init:', { provider: this.provider });
      this.client = new claiming.Client(this.provider.wallet, claiming.DEVNET);
      const mint = Keypair.generate();
      await this.createMint(
        mint,
        this.provider.wallet,
        1000000000,
        9,
      );
      console.log('init:', { mint: this.mint });
      this.config = await this.client.createConfig();
      console.log('init:');
      let tx = await this.provider.connection.requestAirdrop(this.userWallet.publicKey, 5 * LAMPORTS_PER_SOL);
      console.log('init:');
      await this.provider.connection.confirmTransaction(tx);
      console.log('init:');
      tx = await this.provider.connection.requestAirdrop(this.userWallet.publicKey, 5 * LAMPORTS_PER_SOL);
      console.log('init:');
      await this.provider.connection.confirmTransaction(tx);
      console.log('init:');
      const merkle = await this.generateMerkle(this.userWallet);
      console.log('init:');
      this.merkleData = merkle[0];
      this.claimingUsers = merkle[1];
    } catch (e) {
      console.error(e);
    }
  }

  success(message: string) {
    this.testResults.push({ success: true, message })
  }

  fail(message: string) {
    this.testResults.push({ success: true, message })
  }

  async checkAddAdminByUser() {
    const message = 'should not allow to add admin by user';
    try {
      const result = await this.userClient.addAdmin(this.admin.publicKey);
      console.log('checkAddAdminByUser:', { result });
      this.fail(message);
    } catch (e: any) {
      if (e.code === 6005) this.success(message);
    }
  }

  async checkAddAdminByOwner() {
    const message = 'should add admin by owner';
    try {
      const result = await this.client.addAdmin(this.admin.publicKey);
      console.log('checkAddAdminByOwner:', { result });
      const configAccount: any = await this.program.account.config.fetch(this.config);
      const [newAdmin] = configAccount.admins.filter((a: any) => a && a.equals(this.admin.publicKey));
      if (newAdmin) this.success(message);
      this.fail(message);
    } catch (e: any) {
      this.fail(message);
    }
  }

    // it('should add admin by owner', async function () {
    //   await client.addAdmin(admin.publicKey);
    //
    //   const configAccount = await program.account.config.fetch(config);
    //   const [newAdmin] = configAccount.admins.filter((a) => a && a.equals(admin.publicKey));
    //   assert.ok(newAdmin);
    // });
    //
    // it('should not allow to remove admin by user', async function () {
    //   await assert.rejects(
    //     async () => {
    //       await userClient.removeAdmin(admin.publicKey);
    //     },
    //     (err) => {
    //       assert.equal(err.code, 6005);
    //       return true;
    //     }
    //   );
    // });
    //
    // it('should remove admin by owner', async function () {
    //   await client.removeAdmin(admin.publicKey);
    //
    //   const configAccount = await program.account.config.fetch(config);
    //   const maybeNewAdmin = configAccount.admins.filter((a) => a && a.equals(admin.publicKey));
    //   assert.deepStrictEqual(maybeNewAdmin, []);
    // });
}
