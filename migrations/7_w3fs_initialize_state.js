const utils = require('./utils')
const ethUtils = require('ethereumjs-util')
const Registry = artifacts.require("Registry")
const DelegateShareFactory = artifacts.require("DelegateShareFactory")
const DelegateShare = artifacts.require("DelegateShare")
const Governance = artifacts.require('Governance')
const GovernanceProxy = artifacts.require('GovernanceProxy')
const SystemReward = artifacts.require("SystemReward")
const W3fsStakingNFT = artifacts.require("W3fsStakingNFT")
const W3fsStakeManager = artifacts.require('W3fsStakeManager')
const W3fsStorageManager = artifacts.require('W3fsStorageManager')
const SlashingManager = artifacts.require('SlashingManager')
const W3fsStakingInfo = artifacts.require('W3fsStakingInfo')
const w3fsValidators = require('../miner_validators')


async function updateContractMap(governance, registry, nameHash, value) {
    return governance.update(
        registry.address,
        registry.contract.methods.updateContractMap(nameHash, value).encodeABI()
    );
}

async function getW3fsStakeManager() {
    const contractAddresses = utils.getContractAddresses();
    return W3fsStakeManager.at(contractAddresses.w3fsStakeManager);
}

async function getW3fsStakingNFT() {
    const contractAddresses = utils.getContractAddresses();
    return W3fsStakingNFT.at(contractAddresses.w3fsStakingNFT);
}

async function getSystemReward() {
    const contractAddresses = utils.getContractAddresses();
    return SystemReward.at(contractAddresses.systemReward);
}

async function getSlashingManager() {
    const contractAddresses = utils.getContractAddresses();
    return SlashingManager.at(contractAddresses.slashingManager);
}

async function getW3fsStorageManager(){
    const contractAddresses = utils.getContractAddresses();
    return W3fsStorageManager.at(contractAddresses.w3fsStorageManager);
}

async function getW3fsStakingInfo() {
    const contractAddresses = utils.getContractAddresses();
    return W3fsStakingInfo.at(contractAddresses.w3fsStakingInfo);
}



module.exports = async function (deployer, network, accounts) {
    deployer.then(async () => {
        const contractAddresses = utils.getContractAddresses();
        const governance = await Governance.at(contractAddresses.governanceProxy);
        const registry = await Registry.at(contractAddresses['registry']);
        const w3fsStakingNFTContract = await getW3fsStakingNFT();
        const w3fsStakeManagerContract = await getW3fsStakeManager();
        const systemRewardContract = await getSystemReward();
        const slashingManagerContract = await getSlashingManager();
        const w3fsStorageManagerContract = await getW3fsStorageManager();
        const w3fsStakingInfoContract = await getW3fsStakingInfo();

        console.log("=========== start updateContractMap ===================")

        await updateContractMap(
            governance,
            registry,
            ethUtils.keccak256(Buffer.from("delegateShare", "utf8")),
            contractAddresses.delegateShare
        )

        await updateContractMap(
            governance,
            registry,
            ethUtils.keccak256(Buffer.from("w3fsStakeManager", "utf8")),
            contractAddresses.w3fsStakeManager
        )

        await updateContractMap(
            governance,
            registry,
            ethUtils.keccak256(Buffer.from("systemReward", "utf8")),
            contractAddresses.systemReward
        )

        await updateContractMap(
            governance,
            registry,
            ethUtils.keccak256(Buffer.from("w3fsStorageManager", "utf8")),
            contractAddresses.w3fsStorageManager
        )

        await updateContractMap(
            governance,
            registry,
            ethUtils.keccak256(Buffer.from("slashingManager", "utf8")),
            contractAddresses.slashingManager
        )

        // ********************** init W3fsStakingInfo **************************
        await w3fsStakingInfoContract.initialize(contractAddresses.registry).then(function(result, error){
            if (!error) {
                console.log("W3fsStakingInfo.initialize successful ! tx = " + result.tx)
            } else {
                console.log(error);
            }
        });


        // ***************** 设置 W3fsStakingNFT 只能 w3fsStakeManagerProxy地址访问
        await w3fsStakingNFTContract.transferOwnership(contractAddresses.w3fsStakeManager).then(function (result, error) {
            if (!error) {
                console.log("w3fsStakingNFT.transferOwnership successful ! tx = " + result.tx)
            } else {
                console.log(error);
            }
        });

        // **************************** init W3fsStakeManager ************************
        await w3fsStakeManagerContract.initialize(
            accounts[0],
            Registry.address,
            contractAddresses.mrc20,
            contractAddresses.w3fsStakingNFT,
            contractAddresses.governanceProxy,
            contractAddresses.w3fsStakingInfo,
            contractAddresses.delegateShareFactory,
            contractAddresses.w3fsStorageManager
        ).then(function (result, error) {
            if (!error) {
                console.log("w3fsStakeManager.initialize successful ! tx = " + result.tx)
            } else {
                console.log(error);
            }
        });

        // **************************** 设置 system init ****************************
        await systemRewardContract.initialize(
            contractAddresses.governanceProxy,
            contractAddresses.registry
        ).then(function (result, error) {
            if (!error) {
                console.log("systemReward.initialize() successful ! tx = " + result.tx)
            } else {
                console.log(error);
            }
        });

        // ************************ 设置 slashingManager init ***********************
        await slashingManagerContract.initialize(
            contractAddresses.registry,
            contractAddresses.governanceProxy,
            contractAddresses.w3fsStakingInfo,
        ).then(function(result,error){
            if (!error) {
                console.log("slashingManager.initialize() successful ! tx = " + result.tx)
            } else {
                console.log(error);
            }
        });

        // ********************** 设置 w3fsStorageManager init *********************
        await w3fsStorageManagerContract.initialize(
            accounts[0],
            contractAddresses.registry,
            contractAddresses.governanceProxy,
            contractAddresses.w3fsStakingInfo
        ).then(function(result, error){
            if (!error) {
                console.log("w3fsStorageManager.initialize() successful ! tx = " + result.tx)
            } else {
                console.log(error);
            }
        });
        for(let i = 0 ; i < w3fsValidators.length ; i++) {
            let signer = w3fsValidators[i]['signer']
            let storageSize = w3fsValidators[i]['storageSize']
            console.log('signer = ' , signer , 'storageSize = ' , storageSize)
            await w3fsStorageManagerContract.updateStoragePromise(signer, storageSize).then(function(result,error){
                if (!error) {
                    console.log("updateStoragePromise - ", signer, " success !")
                }
            });
        }

    })
}

