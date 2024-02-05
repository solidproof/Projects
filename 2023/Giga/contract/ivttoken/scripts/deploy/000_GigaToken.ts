import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"


const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    await deploy("GigaToken", {
        from: deployer,
        args: [],
        log: true,
        skipIfAlreadyDeployed: false,
    })
} 

export default func;