import { keccak256 } from 'ethereumjs-util';
import * as anchor from '@project-serum/anchor';

export type MerkleTreeElement = {
  address: anchor.web3.PublicKey,
  amount: number,
};

export type MerkleProof = {
  proofs: number[][],
  address: anchor.web3.PublicKey,
  amount: anchor.BN,
};

export type MerkleData = {
  root: number[],
  totalTokens: number,
  proofs: MerkleProof[],
};

export function getMerkleProof(data: MerkleTreeElement[]): MerkleData {
  let totalTokens = 0;
  const elements = data.map((x) => {
    const address = x.address;
    const amount = new anchor.BN(x.amount);
    const leaf = MerkleTree.toLeaf(address, amount);
    totalTokens += x.amount * 1;
    return {
      leaf,
      address,
      amount
    };
  });

  const merkleTree = new MerkleTree(elements.map(x => x.leaf));
  const root = merkleTree.getRoot();

  let proofs = elements.map((x: any) => {
    return {
      proofs: merkleTree.getProof(x.leaf),
      index: x.index,
      address: x.address,
      amount: x.amount
    };
  });

  const merkleData = {
    root: root,
    totalTokens: totalTokens,
    proofs,
  };

  return merkleData;
}

export class MerkleTree {
  elements: Buffer[];
  layers: any;

  constructor(elements: Buffer[]) {
    // Filter empty strings
    this.elements = elements.filter(el => el);

    // Sort elements
    this.elements.sort(Buffer.compare);
    // Deduplicate elements
    this.elements = this.bufDedup(this.elements);

    // Create layers
    this.layers = this.getLayers(this.elements);
  }

  getLayers(elements: Buffer[]) {
    if (elements.length === 0) {
      return [['']];
    }

    const layers = [];
    layers.push(elements);

    // Get next layer until we reach the root
    while (layers[layers.length - 1].length > 1) {
      layers.push(this.getNextLayer(layers[layers.length - 1]));
    }

    return layers;
  }

  getNextLayer(elements: Buffer[]) {
    return elements.reduce((layer: any, el: any, idx: any, arr: any) => {
      if (idx % 2 === 0) {
        // Hash the current element with its pair element
        layer.push(MerkleTree.combinedHash(el, arr[idx + 1]));
      }

      return layer;
    }, []);
  }

  public static verifyProof(account: any, amount: any, proof: any, root: any) {
    let computedHash = MerkleTree.toLeaf(account, amount);
    for (const item of proof) {
      computedHash = MerkleTree.combinedHash(computedHash, item);
      console.log(computedHash);
    }

    return computedHash.equals(root);
  }

  public static toLeaf(account: anchor.web3.PublicKey, amount: anchor.BN): Buffer {
    const buf = Buffer.concat([
      account.toBuffer(),
      Buffer.from(amount.toArray('be', 8)),
    ]);
    return keccak256(buf);
  }

  static combinedHash(first: any, second: any) {
    if (!first) { return second; }
    if (!second) { return first; }

    return keccak256(MerkleTree.sortAndConcat(first, second));
  }

  getRoot() {
    return this.layers[this.layers.length - 1][0];
  }

  getProof(el: any) {
    let idx = this.bufIndexOf(el, this.elements);

    if (idx === -1) {
      throw new Error('Element does not exist in Merkle tree');
    }

    return this.layers.reduce((proof: any, layer: any) => {
      const pairElement = this.getPairElement(idx, layer);

      if (pairElement) {
        proof.push(pairElement);
      }

      idx = Math.floor(idx / 2);

      return proof;
    }, []);
  }

  getPairElement(idx: any, layer: any) {
    const pairIdx = idx % 2 === 0 ? idx + 1 : idx - 1;

    if (pairIdx < layer.length) {
      return layer[pairIdx];
    } else {
      return null;
    }
  }

  bufIndexOf(el: any, arr: any) {
    let hash;

    // Convert element to 32 byte hash if it is not one already
    if (el.length !== 32 || !Buffer.isBuffer(el)) {
      hash = keccak256(el);
    } else {
      hash = el;
    }

    for (let i = 0; i < arr.length; i++) {
      if (hash.equals(arr[i])) {
        return i;
      }
    }

    return -1;
  }

  bufDedup(elements: any) {
    return elements.filter((el: any, idx: any) => {
      return idx === 0 || !elements[idx - 1].equals(el);
    });
  }

  static sortAndConcat(...args: any) {
    return Buffer.concat([...args].sort(Buffer.compare));
  }
}
