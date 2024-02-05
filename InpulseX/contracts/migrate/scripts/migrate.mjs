import { ethers } from "ethers";
import fs from "fs";
import dotenv from "dotenv";
import cliProgress from "cli-progress";
import { getChunks } from "./common.mjs";
import { NonceManager } from "@ethersproject/experimental";

dotenv.config();

const balances = JSON.parse(fs.readFileSync("./balances.json"));
const provider = new ethers.providers.JsonRpcProvider(process.env.PROVIDER);
const signer = new ethers.Wallet(process.env.ADMIN_KEY, provider);
const manager = new NonceManager(signer);

const { migrationContractAddress } = JSON.parse(
  fs.readFileSync("./config.json")
);
const abi = [
  "function bulkAirdrop(address[] addresses, uint256[] balances, uint256 length) external",
];

const contract = new ethers.Contract(migrationContractAddress, abi, manager);

const airdrop = async (addresses, balances) => {
  return await contract.bulkAirdrop(addresses, balances, balances.length);
};

const excluded = [];

const entries = Object.entries(balances).filter(
  ([address]) => !excluded.includes(address)
);
const chunks = getChunks(entries, 200);

const bar = new cliProgress.SingleBar({}, cliProgress.Presets.shades_classic);
bar.start(entries.length, 0);

await Promise.all(
  [...chunks].map(async (chunk) => {
    const addresses = chunk.map((d) => d[0]);
    const balances = chunk.map((d) => ethers.BigNumber.from(d[1]).div(10000));
    await airdrop(addresses, balances);
    bar.increment(chunk.length);
  })
);

bar.stop();
