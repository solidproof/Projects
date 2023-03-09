import { ethers } from "ethers";
import fs from "fs";
import dotenv from "dotenv";
import cliProgress from "cli-progress";
import { getChunks } from "./common.mjs";

dotenv.config();

const exported = JSON.parse(fs.readFileSync("./bscScanExport.json"));
const holders = exported.map((line) => line.HolderAddress);
const provider = new ethers.providers.JsonRpcProvider(process.env.PROVIDER);

const { blockTag, v1TokenAddress } = JSON.parse(
  fs.readFileSync("./config.json")
);

const abi = ["function balanceOf(address user) view returns (uint256)"];
const contract = new ethers.Contract(v1TokenAddress, abi, provider);

const getBalance = async (user) => {
  const balance = await contract.balanceOf(user, { blockTag });
  return balance.toString();
};

const balances = {};
const bar = new cliProgress.SingleBar({}, cliProgress.Presets.shades_classic);

bar.start(holders.length, 0);

const setBalance = async (user) => {
  balances[user] = await getBalance(user);
  bar.increment();
};

const chunks = getChunks(holders, 24);

for (const chunk of chunks) {
  await Promise.all(chunk.map(setBalance));
}

bar.stop();

fs.writeFileSync("./balances.json", JSON.stringify(balances));
