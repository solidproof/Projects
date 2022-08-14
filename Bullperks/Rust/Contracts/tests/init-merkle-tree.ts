import * as anchor from '@project-serum/anchor';
import * as serumCmn from "@project-serum/common";
import { TokenInstructions } from '@project-serum/serum';
import * as spl from "@solana/spl-token";

import * as merkle from './merkle-tree';

const TOKEN_PROGRAM_ID = TokenInstructions.TOKEN_PROGRAM_ID;

export const provider = anchor.Provider.env();

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
        TOKEN_PROGRAM_ID,
    );
    return mint;
}

export async function generateMerkle(mint: spl.Token) {
    const data = [];
    for (var i = 0; i < 5; i++) {
        const address = await serumCmn.createTokenAccount(provider, mint.publicKey, provider.wallet.publicKey);
        data.push({ address, amount: i });
    }
    return merkle.getMerkleProof(data);
}

(async () => {
    const mint = await createMint(provider);
    const merkleData = await generateMerkle(mint);

    console.log("Mint", mint.publicKey.toString());
    console.log("Root", JSON.stringify(merkleData.root));
    for (const data of merkleData.proofs) {
        console.log("======================");
        console.log("User", data.address.toString());
        console.log("Amount", data.amount.toNumber());
        console.log("Proofs");
        for (const proof of data.proofs) {
            console.log(JSON.stringify(proof));
        }
    }
})();
