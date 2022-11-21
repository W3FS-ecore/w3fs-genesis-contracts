const MRC20 = artifacts.require("MRC20");
const utils = require('./utils');

module.exports = function (deployer, network, accounts) {
    deployer.then(async () => {
        await updateMRC20(deployer, network, accounts);
    })
};

async function updateMRC20(deployer, network, accounts){
    const contractAddresses = utils.getContractAddresses();
    const w3fsToken = await MRC20.at('0x0000000000000000000000000000000000001010');
    const owner = await w3fsToken.owner();
    if (owner === '0x0000000000000000000000000000000000000000') {
        // 控制权限
        await w3fsToken.initialize(contractAddresses.childChainManager, contractAddresses.rootW3fsToken);
    }
}




