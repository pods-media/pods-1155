export const signDeployFactory = ({ account, deterministicDeploymentConfig: config, implementationAddress, owner, chainId, }) => account.signTypedData({
    types: {
        createProxy: [
            { name: "proxyShimSalt", type: "bytes32" },
            { name: "proxySalt", type: "bytes32" },
            { name: "proxyCreationCode", type: "bytes" },
            { name: "implementationAddress", type: "address" },
            { name: "owner", type: "address" },
        ],
    },
    message: {
        proxyShimSalt: config.proxyShimSalt,
        implementationAddress,
        proxyCreationCode: config.proxyCreationCode,
        proxySalt: config.proxySalt,
        owner: owner,
    },
    primaryType: "createProxy",
    domain: {
        chainId,
        name: "DeterministicProxyDeployer",
        version: "1",
        verifyingContract: config.proxyDeployerAddress,
    },
});
export const signGenericDeploy = ({ account, config, chainId, initCall, }) => account.signTypedData({
    types: {
        createGenericContract: [
            { name: "salt", type: "bytes32" },
            { name: "creationCode", type: "bytes" },
            { name: "initCall", type: "bytes" },
        ],
    },
    message: {
        salt: config.salt,
        creationCode: config.creationCode,
        initCall,
    },
    primaryType: "createGenericContract",
    domain: {
        chainId,
        name: "DeterministicProxyDeployer",
        version: "1",
        verifyingContract: config.proxyDeployerAddress,
    },
});
