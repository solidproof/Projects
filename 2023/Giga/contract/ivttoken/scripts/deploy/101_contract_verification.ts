import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { NomicLabsHardhatPluginError } from "hardhat/plugins"
import { CONTRACTS, CONFIGURATION } from "../constants"

const delay = (ms: number | undefined) => new Promise(resolve => setTimeout(resolve, ms))

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre
    const { deployer, secondSigner, thirdSigner } = await getNamedAccounts()
    const signer = await ethers.provider.getSigner(deployer)

    console.log("Account balance:", ethers.utils.formatEther((await signer.getBalance()).toString()) + " ETH")

    const network = await ethers.provider.getNetwork()

    const gigaTokenDeployment = await deployments.get(CONTRACTS.gigaToken)
    const multisigDeployment = await deployments.get(CONTRACTS.multisig)
    const verifierDeployment = await deployments.get(CONTRACTS.verifier)

    let secondAddress = secondSigner;
    let thirdAddress = thirdSigner;
    
    if (network.chainId !== CONFIGURATION.hardhatChainId) {
        secondAddress = CONFIGURATION.secondSignerAddress;
        thirdAddress = CONFIGURATION.thirdSignerAddress;

        try {
            console.log("Sleepin' for 30 seconds to wait for the chain to be ready...")
            await delay(30e3) // 30 seconds delay to allow the network to be synced
            await hre.run("verify:verify", {
                address: gigaTokenDeployment.address,
                constructorArguments: []
            })
            console.log("Verified -- GigaToken")
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- GigaToken")
                console.log(error.message)
                console.log(error)
            } else {
                throw error // let others bubble up
            }
        }

        try {
            console.log("Sleepin' for 30 seconds to wait for the chain to be ready...")
            await delay(30e3) // 30 seconds delay to allow the network to be synced
            await hre.run("verify:verify", {
                address: multisigDeployment.address,
                constructorArguments: [secondAddress, thirdAddress]
            })
            console.log("Verified -- Multisig")
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- Multisig")
                console.log(error.message)
                console.log(error)
            } else {
                throw error // let others bubble up
            }
        }

        try {
            console.log("Sleepin' for 30 seconds to wait for the chain to be ready...")
            await delay(30e3) // 30 seconds delay to allow the network to be synced
            await hre.run("verify:verify", {
                address: verifierDeployment.address,
                constructorArguments: []
            })
            console.log("Verified -- Verifier")
        } catch (error) {
            if (error instanceof NomicLabsHardhatPluginError) {
                // specific error
                console.log("Error verifying -- Verifier")
                console.log(error.message)
                console.log(error)
            } else {
                throw error // let others bubble up
            }
        }
    }
}

func.tags = ["verify"]

export default func
