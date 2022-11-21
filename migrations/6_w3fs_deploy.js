const utils = require('./utils')
const ethUtils = require('ethereumjs-util')

const Governance = artifacts.require('Governance')
const GovernanceProxy = artifacts.require('GovernanceProxy')
const W3fsStakeManager = artifacts.require('W3fsStakeManager')
const W3fsStakeManagerProxy = artifacts.require('W3fsStakeManagerProxy')
const W3fsStorageManager = artifacts.require('W3fsStorageManager')
const SlashingManager = artifacts.require('SlashingManager')
const MRC20 = artifacts.require("MRC20")
const W3fsStakingNFT = artifacts.require("W3fsStakingNFT")
const W3fsStakingInfo = artifacts.require("W3fsStakingInfo")
const Registry = artifacts.require("Registry")
const DelegateShareFactory = artifacts.require("DelegateShareFactory")
const DelegateShare = artifacts.require("DelegateShare")
const SystemReward = artifacts.require("SystemReward")

module.exports = async function (deployer, network, accounts) {
    deployer.then(async () => {

        const contractAddresses = utils.getContractAddresses();
        console.log("***********************deploy start *******************")
        console.log("deploy author :" + accounts[0])

        // *********************** Governance deplay *******************
        await deployer.deploy(Governance);
        await deployer.deploy(GovernanceProxy, Governance.address, Buffer.from(''));

        // *********************** W3fsStakingNFT deplay ***************
        await deployer.deploy(W3fsStakingNFT, 'W3fs Miner', 'NM');

        // ********************** Registry deplay *********************
        await deployer.deploy(Registry, GovernanceProxy.address);

        // *********************** W3fsStakingInfo deplay **************
        //await deployer.deploy(W3fsStakingInfo, Registry.address);


        // *********************** delegate deplay *********************
        await deployer.deploy(DelegateShare)
        await deployer.deploy(DelegateShareFactory)


        // =========================== test deplay =============================
        //await deployer.deploy(W3fsStakeManager);
        //await deployer.deploy(SystemReward, {from : accounts[0], value : web3.utils.toWei('10')})
        //await deployer.deploy(W3fsStorageManager)
        //await deployer.deploy(SlashingManager)
        // ====================================================================

        contractAddresses['mrc20'] = '0x0000000000000000000000000000000000001010';
        contractAddresses['governance'] = Governance.address;
        contractAddresses['governanceProxy'] = GovernanceProxy.address;
        contractAddresses['registry'] = Registry.address;
        contractAddresses['delegateShare'] = DelegateShare.address;
        contractAddresses['delegateShareFactory'] = DelegateShareFactory.address;
        contractAddresses['w3fsStakingNFT'] = W3fsStakingNFT.address;


        //contractAddresses['w3fsStakeManager'] = W3fsStakeManager.address;
        //contractAddresses['systemReward'] = SystemReward.address;
        //contractAddresses['w3fsStorageManager'] = W3fsStorageManager.address;
        //contractAddresses['slashingManager'] = SlashingManager.address;
        //contractAddresses['w3fsStakingInfo'] = W3fsStakingInfo.address;

        contractAddresses['w3fsStorageManager'] = '0x0000000000000000000000000000000000001002';
        contractAddresses['w3fsStakeManager'] = '0x0000000000000000000000000000000000001003';
        contractAddresses['systemReward'] = '0x0000000000000000000000000000000000001004';
        contractAddresses['slashingManager'] = '0x0000000000000000000000000000000000001005';
        contractAddresses['w3fsStakingInfo'] = '0x0000000000000000000000000000000000001006';


        console.log("***********************deploy end *******************")
        console.log(JSON.stringify(contractAddresses, null, 10));
        utils.writeContractAddresses(contractAddresses); // write to file
    })
}
