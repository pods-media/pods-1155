import { encodeFunctionData, parseAbi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { glob } from "glob";
import * as path from "path";
import * as dotenv from "dotenv";
import { writeFile, readFile } from "fs/promises";
import { signDeployFactory, signGenericDeploy, } from "../package/deployment.js";
import { fileURLToPath } from "url";
import { dirname } from "path";
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// Load environment variables from `.env.local`
dotenv.config({ path: path.resolve(__dirname, "../.env") });
async function signAndSaveSignatures({ turnkeyAccount, chainConfigs, proxyName, chainId, }) {
    const configFolder = path.resolve(__dirname, `../deterministicConfig/${proxyName}/`);
    const configFile = path.join(configFolder, "params.json");
    const deterministicDeployConfig = JSON.parse(await readFile(configFile, "utf-8"));
    const deploymentConfig = {
        proxyDeployerAddress: deterministicDeployConfig.proxyDeployerAddress,
        proxySalt: deterministicDeployConfig.proxySalt,
        proxyShimSalt: deterministicDeployConfig.proxyShimSalt,
        proxyCreationCode: deterministicDeployConfig.proxyCreationCode,
    };
    const chainConfig = chainConfigs.find((x) => x.chainId === chainId);
    if (!chainConfig) {
        return;
    }
    const signature = await signDeployFactory({
        account: turnkeyAccount,
        implementationAddress: chainConfig.implementationAddress,
        owner: chainConfig.owner,
        chainId: chainConfig.chainId,
        deterministicDeploymentConfig: deploymentConfig,
    });
    const existingSignatures = JSON.parse(await readFile(path.join(configFolder, "signatures.json"), "utf-8"));
    const updated = {
        ...existingSignatures,
        [chainId]: signature,
    };
    // aggregate above to object of key value pair indexed by chain id as number:
    // write as json to ../deterministicConfig/factoryDeploySignatures.json:
    await writeFile(path.join(configFolder, "signatures.json"), JSON.stringify(updated, null, 2));
}
async function signAndSaveUpgradeGate({ turnkeyAccount, chainConfigs, proxyName, chainId, }) {
    const configFolder = path.resolve(__dirname, `../deterministicConfig/${proxyName}/`);
    const configFile = path.join(configFolder, "params.json");
    const deterministicDeployConfig = JSON.parse(await readFile(configFile, "utf-8"));
    const deploymentConfig = {
        creationCode: deterministicDeployConfig.creationCode,
        salt: deterministicDeployConfig.salt,
        deployerAddress: deterministicDeployConfig.deployerAddress,
        upgradeGateAddress: deterministicDeployConfig.upgradeGateAddress,
        proxyDeployerAddress: deterministicDeployConfig.proxyDeployerAddress,
    };
    const upgradeGateAbi = parseAbi(["function initialize(address owner)"]);
    const chainConfig = chainConfigs.find((x) => x.chainId === chainId);
    if (!chainConfig) {
        throw new Error(`No chain config found for chain id ${chainId}`);
    }
    const initCall = encodeFunctionData({
        abi: upgradeGateAbi,
        functionName: "initialize",
        args: [chainConfig.owner],
    });
    console.log("signing", { turnkeyAccount, deploymentConfig });
    const signature = await signGenericDeploy({
        account: turnkeyAccount,
        chainId: chainConfig.chainId,
        config: deploymentConfig,
        initCall,
    });
    const existingSignatures = JSON.parse(await readFile(path.join(configFolder, "signatures.json"), "utf-8"));
    const updated = {
        ...existingSignatures,
        [chainId]: signature,
    };
    // write as json to ../deterministicConfig/factoryDeploySignatures.json:
    await writeFile(path.join(configFolder, "signatures.json"), JSON.stringify(updated, null, 2));
}
const getChainConfigs = async () => {
    const chainConfigsFiles = await glob(path.resolve(__dirname, "../chainConfigs/*.json"));
    const chainConfigs = await Promise.all(chainConfigsFiles.map(async (chainConfigFile) => {
        const chainId = parseInt(path.basename(chainConfigFile).split(".")[0]);
        // read file and process JSON contents:
        const fileContents = JSON.parse(await readFile(chainConfigFile, 'utf-8'));
        return {
            chainId,
            owner: fileContents["FACTORY_OWNER"],
        };
    }));
    return chainConfigs;
};
const getFactoryImplConfigs = async () => {
    const addresseFiles = await glob(path.resolve(__dirname, "../addresses/*.json"));
    const chainConfigs = await Promise.all(addresseFiles.map(async (addressConfigFile) => {
        const chainId = parseInt(path.basename(addressConfigFile).split(".")[0]);
        // read file and process JSON contents:
        const fileContents = JSON.parse(await readFile(addressConfigFile, 'utf-8'));
        // read chain config file as json, which is located at: ../chainConfigs/${chainId}.json:
        const chainConfig = JSON.parse(await readFile(path.resolve(__dirname, `../chainConfigs/${chainId}.json`), 'utf-8'));
        return {
            chainId,
            implementationAddress: fileContents["FACTORY_IMPL"],
            owner: chainConfig["FACTORY_OWNER"],
        };
    }));
    return chainConfigs;
};
const getPreminterImplConfigs = async () => {
    const addresseFiles = await glob(path.resolve(__dirname, "../addresses/*.json"));
    const chainConfigs = await Promise.all(addresseFiles.map(async (addressConfigFile) => {
        const chainId = parseInt(path.basename(addressConfigFile).split(".")[0]);
        // read file and process JSON contents:
        const fileContents = JSON.parse(await readFile(addressConfigFile, 'utf-8'));
        // read chain config file as json, which is located at: ../chainConfigs/${chainId}.json:
        const chainConfig = JSON.parse(await readFile(path.resolve(__dirname, `../chainConfigs/${chainId}.json`), 'utf-8'));
        return {
            chainId,
            implementationAddress: fileContents["PREMINTER_IMPL"],
            owner: chainConfig["FACTORY_OWNER"],
        };
    }));
    return chainConfigs.filter((x) => x.implementationAddress !== undefined);
};
function getChainIdPositionalArg() {
    // parse chain id as first argument:
    const chainIdArg = process.argv[2];
    if (!chainIdArg) {
        throw new Error("Must provide chain id as first argument");
    }
    return parseInt(chainIdArg);
}
async function main() {
    // Create the Viem custom account
    const turnkeyAccount = privateKeyToAccount(process.env.SIGNER_PRIVATE_KEY);
    const chainId = getChainIdPositionalArg();
    await signAndSaveSignatures({
        turnkeyAccount,
        chainConfigs: await getFactoryImplConfigs(),
        proxyName: "factoryProxy",
        chainId,
    });
    await signAndSaveSignatures({
        turnkeyAccount,
        chainConfigs: await getPreminterImplConfigs(),
        proxyName: "premintExecutorProxy",
        chainId,
    });
    await signAndSaveUpgradeGate({
        turnkeyAccount,
        chainConfigs: await getChainConfigs(),
        proxyName: "upgradeGate",
        chainId,
    });
}
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
