import fs from "fs";
import path from "path";
import hre from "hardhat";

const frontendPaths = [path.join(__dirname, '../front/contracts')]

function mkDirIfNotExists(dirPath: any) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

/**
 * Writes smart contract ABI and deployment address to the frontend contracts folder,
 * which can be specified in `project.config.js`
 * @param {string} name Hardhat artifact name (coincides with the contract name)
 * @param {string} address deployed smart contract address
 */
export async function writeArtifactToFrontend(name: string, address: any) {
  const { abi } = await hre.artifacts.readArtifact(name);
  const contractData = JSON.stringify({
    address,
    abi,
  });
  console.log(`${name} ABI and address were written to`);
  frontendPaths.forEach((frontendPath: any) => {
    mkDirIfNotExists(frontendPath);
    const fileName = path.join(frontendPath, `${name}.json`);
    fs.writeFileSync(fileName, contractData, 'utf8');
    console.log(fileName);
  });
}
