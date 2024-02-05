import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, CONFIGURATION } from "../constants";
import { writeArtifactToFrontend } from "../writeArtifactToFrontend";


const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer, secondSigner, thirdSigner } = await getNamedAccounts();

    const network = await hre.ethers.provider.getNetwork();

    let secondAddress = secondSigner;
    let thirdAddress = thirdSigner;

    if (network.chainId !== CONFIGURATION.hardhatChainId) {
        secondAddress = CONFIGURATION.secondSignerAddress;
        thirdAddress = CONFIGURATION.thirdSignerAddress;
    }

    const multisig = await deploy(CONTRACTS.multisig, {
        from: deployer,
        args: [secondAddress, thirdAddress],
        log: true,
        skipIfAlreadyDeployed: true,
    });

    await writeArtifactToFrontend(CONTRACTS.multisig, multisig.address);
};

func.tags = [CONTRACTS.multisig, "migration", "production"];

export default func;