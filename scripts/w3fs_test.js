const utils = require('../migrations/utils')
const Governance = artifacts.require('Governance')
const W3fsStakeManager = artifacts.require('W3fsStakeManager')
const SystemReward = artifacts.require("SystemReward")
const DelegateShare = artifacts.require("DelegateShare")
const SlashingManager = artifacts.require('SlashingManager')
const W3fsStorageManager = artifacts.require('W3fsStorageManager')
const ethers = require('ethers')
const RLP = require('rlp')

async function getW3fsStorageManager() {
    const contractAddress = utils.getContractAddresses()
    return W3fsStorageManager.at(contractAddress.w3fsStorageManager)
}

async function getSlashingManagerContract() {
    const contractAddresses = utils.getContractAddresses();
    return SlashingManager.at(contractAddresses.slashingManager);
}

async function getGovernanceProxyContract() {
    const contractAddresses = utils.getContractAddresses();
    return Governance.at(contractAddresses.governanceProxy);
}

async function getW3fsStakeManagerContract() {
    const contractAddresses = utils.getContractAddresses();
    return W3fsStakeManager.at(contractAddresses.w3fsStakeManager);
}

async function getSystemRewardContract() {
    const contractAddresses = utils.getContractAddresses();
    return SystemReward.at(contractAddresses.systemReward);
}

async function getDelegateShareContractByMinerId(minerId) {
    const contractAddresses = utils.getContractAddresses();
    const w3fsStakeManager = await getW3fsStakeManagerContract();
    const minerObj = await w3fsStakeManager.storageMiners(minerId);
    const contractAddress = minerObj.contractAddress;
    return DelegateShare.at(contractAddress);
}

async function getEtherProvider() {
    let currentProvider = new web3.providers.HttpProvider('http://localhost:8545');
    return new ethers.providers.Web3Provider(currentProvider);
}

function initRlpData() {
    const sealVote = [
        {
            sectorInx: 0x0000000000000000000000000000000000000000,
            sealProofType: 0x0000000000000000000000000000000000000007,
            sealedCID: Buffer.alloc(32),
            proof: Buffer.alloc(32)
        }
    ]
    let n = sealVote.length;
    let vals = [];
    for (let i = 0; i < n; i++) {
        vals.push([
            sealVote[i].sectorInx,
            sealVote[i].sealProofType,
            sealVote[i].sealedCID,
            sealVote[i].proof
        ]);
    }
    return web3.utils.bytesToHex(RLP.encode(vals));
}


async function Test00Gov2() {
    const contractAddresses = utils.getContractAddresses();
    const governance = await Governance.at(contractAddresses.governance);
    const governanceProxy = await getGovernanceProxyContract();
    console.log(await governance.owner());
    console.log(await governanceProxy.owner());
}

// stakeFor方法测试
async function TestStakeManager01() {
    //const pubKey = utils.privToPub("0xe5861347faf0f99409666f0f27dee18832624d2f3d16f1f9f5becda9c025669d");
    const pubKey = utils.privToPub("0x4c878db38f617165586623ce064078f6bfe253e1e63a7e4797d10f0d50831637");
    const accounts = await web3.eth.getAccounts();
    const w3fsStakeManager = await getW3fsStakeManagerContract();
    const stakeToken = web3.utils.toWei('10');
    const storageCount = 10 * 512000;
    await w3fsStakeManager.stakeFor(accounts[0], stakeToken, storageCount, true, pubKey,
        {
            from: accounts[0],
            value : stakeToken
        }
    ).then(function (result, error) {
        console.log(error);
        console.log(result);
    });

    await TestStakeSprint();
}

async function TestUnjail(){
    const accounts = await web3.eth.getAccounts();
    const w3fsStakeManager = await getW3fsStakeManagerContract();
    await w3fsStakeManager.unjail(1).then(function(result,error){
        console.log(result);
        console.log(error);
    });
}

async function TestStakeTest() {
    const accounts = await web3.eth.getAccounts();
    const W3fsStakeManager = await getW3fsStakeManagerContract();
    //const minerObj = await w3fsStakeManager.getBorMiners();
    //console.log(JSON.stringify(minerObj));
    //const minerObj = await w3fsStakeManager.storageMiners(2);
    //console.log(JSON.stringify(minerObj));
    /*for (let i = 0; i < 5; i++) {
        const minerObj = await w3fsStakeManager.storageMiners(i);
        if (minerObj.signer != '0x0000000000000000000000000000000000000000') {
            console.log("signer[", minerObj.signer ,"] reward = ", web3.utils.fromWei(minerObj.reward.toString(), 'ether'));
            //console.log("miner[", i, "]=", JSON.stringify(minerObj))
        }
    }*/
    //console.log((await w3fsStakeManager.getCurrentEpoch(200)).toString());
    //console.log(JSON.stringify(await w3fsStakeManager.getBorMiners()));
    //console.log((await w3fsStakeManager.signerToStorageMiner('0xb4551baB04854a09b93492bb61b1B011a82cC27A')).toString());
    //console.log((await w3fsStakeManager.signerToStorageMiner('0xCd372b7D1e5c9892d5d545e4b02521AC096F9456')).toString());
    console.log(await w3fsStakeManager.isActiveMiner('0xb4551baB04854a09b93492bb61b1B011a82cC27A'));
    //console.log(await w3fsStakeManager.isActiveMiner('0xCd372b7D1e5c9892d5d545e4b02521AC096F9456'));
    //console.log(await w3fsStakeManager.isHasRewardMiner('0xb4551baB04854a09b93492bb61b1B011a82cC27A'));
    //console.log(await w3fsStakeManager.isHasRewardMiner('0xb4551baB04854a09b93492bb61b1B011a82cC27A'));
}

// 打印质押信息
async function TestStakeSprint() {
    const accounts = await web3.eth.getAccounts();
    const w3fsStakeManager = await getW3fsStakeManagerContract();
    const contractAddresses = utils.getContractAddresses();
    // 打印所有质押者信息
    for (let i = 0; i < 5; i++) {
        const minerObj = await w3fsStakeManager.storageMiners(i);
        if (minerObj.signer != '0x0000000000000000000000000000000000000000') {
            console.log("miner[", i, "]=", JSON.stringify(minerObj))
        }
    }
    // 打印storageMinerState信息
    const storageMinerState = await w3fsStakeManager.storageMinerState();
    console.log('storageMinerState = ', JSON.stringify(storageMinerState, null, 10));

    // 判断是否是活跃矿工
    const isMiner = await w3fsStakeManager.isActiveMiner(accounts[0]);
    console.log('isMiner = ' + isMiner);

    // 获取验证者(地址+委托量)
    const borMiners = await w3fsStakeManager.getBorMiners();
    console.log('borMiners = ', JSON.stringify(borMiners, null, 10));

    //查看质押后各自后 质押合约和发起者的余额
    console.log("w3fsStakeManager balance = ", await web3.eth.getBalance(contractAddresses.w3fsStakeManager));
    console.log("systemReward balance =", await web3.eth.getBalance(contractAddresses.systemReward));

}

// 奖励提取测试
async function TestClaimRewardsMiner() {
    const accounts = await web3.eth.getAccounts();
    const systemReward = await getSystemRewardContract();
    const w3fsStakeManager = await getW3fsStakeManagerContract();
    await showMinerRewardAndBalance();
    // 提取奖励
    const _reward = web3.utils.toWei('200')
    await systemReward.claimRewardsMiner(_reward).then(function (result, error) {
        console.log(error);
        console.log(result);
    });
    // 打印矿工剩余余额和剩余奖励
    await showMinerRewardAndBalance();
}

// 矿工提取剩余奖励
async function TestClaimLeaverReward() {
    const accounts = await web3.eth.getAccounts();
    const systemReward = await getSystemRewardContract();
    await showMinerRewardAndBalance();
    // 提取奖励
    await systemReward.claimLeaverReward().then(function (result, error) {
        console.log(error);
        console.log(result);
    });
    // 打印矿工剩余余额和剩余奖励
    await showMinerRewardAndBalance();
}

// 测试添加质押
async function TestRestake() {
    const accounts = await web3.eth.getAccounts();
    const w3fsStakeManager = await getW3fsStakeManagerContract();
    await w3fsStakeManager.restake(1, web3.utils.toWei('100'), {
        from: accounts[0],
        value: web3.utils.toWei('100')
    }).then(function (result, error) {
        console.log(result)
        console.log(error)
    });
    await showMinerInfo();
}

async function TestUnStake() {
    const accounts = await web3.eth.getAccounts();
    const w3fsStakeManager = await getW3fsStakeManagerContract();
    await w3fsStakeManager.unstake(1).then(function (result, error) {
        console.log(error);
        console.log(result);
    });
    await showMinerInfo();
}

async function showDelegateShareInfo() {
    web3.utils.fromWei('', 'ether')
    const accounts = await web3.eth.getAccounts();
    const delegateShare = await getDelegateShareContractByMinerId(1);
    console.log('minerId = ', (await delegateShare.minerId()).toString());
    console.log('stakeManagerAdd = ', (await delegateShare.stakeManagerAdd()));
    console.log('balanceof = ', (await delegateShare.balanceOf(accounts[0])).toString());
    console.log('getRewardPerShare = ', (await delegateShare.getRewardPerShare()).toString());
    console.log('LiquidRewards[', accounts[0], "] = ", web3.utils.fromWei((await delegateShare.getLiquidRewards(accounts[0])).toString(), 'ether'));
    console.log('LiquidRewardsMap [ ', accounts[0], "] = ", web3.utils.fromWei((await delegateShare.liquidRewardsMap(accounts[0])).toString(), 'ether'));

    const totalStakeObj = (await delegateShare.getTotalStake(accounts[0]));
    const totalStake = {
        stakeAmount: totalStakeObj[0].toString(),
        rate: totalStakeObj[1].toString()
    }
    console.log(JSON.stringify(totalStake));
    console.log('totalSupply = ', web3.utils.fromWei((await delegateShare.totalSupply()).toString(), 'ether'));
    const unbondNonces = await delegateShare.unbondNonces(accounts[0]);
    const unbondsNew = await delegateShare.unbonds_new(accounts[0], unbondNonces.toString());
    console.log(JSON.stringify(unbondsNew));
}

async function TestBuyVoucher() {
    const contractAddresses = utils.getContractAddresses();
    const delegateShare = await getDelegateShareContractByMinerId(1);
    const accounts = await web3.eth.getAccounts();
    const token = web3.utils.toWei('100');
    await delegateShare.buyVoucher(token, token, {
        from: accounts[0],
        value: token
    }).then(function (result, error) {
        console.log(result);
    });
    await showDelegateShareInfo();
}


// 委托者取回委托
async function TestSellVoucher() {
    const contractAddresses = utils.getContractAddresses();
    const accounts = await web3.eth.getAccounts();
    const delegateShare = await getDelegateShareContractByMinerId(1);
    const token = web3.utils.toWei('20');
    const maxToken = web3.utils.toWei('40');
    await delegateShare.sellVoucher_new(token, maxToken).then(function (result, error) {
        console.log(result);
        console.log(error);
    });
}

async function TestUnstakeClaimTokens() {
    const contractAddresses = utils.getContractAddresses();
    const accounts = await web3.eth.getAccounts();
    const delegateShare = await getDelegateShareContractByMinerId(1);
    const unbondNonces = (await delegateShare.unbondNonces(accounts[0])).toString();
    await delegateShare.unstakeClaimTokens_new(unbondNonces).then(function (result, error) {
        console.log(result);
        console.log(error);
    });
    await showDelegateShareInfo();
}


// 委托者提取奖励
async function TestDelegateWithdrawRewards() {
    const contractAddresses = utils.getContractAddresses();
    const accounts = await web3.eth.getAccounts();
    const systemReward = await getSystemRewardContract();
    await systemReward.withdrawDelegateRewards(1).then(function (result, error) {
        console.log(result);
        console.log(error);
    });
    await showDelegateShareInfo();
}


async function showMinerInfo() {
    const accounts = await web3.eth.getAccounts();
    const w3fsStakeManager = await getW3fsStakeManagerContract();
    for (let i = 0; i < 5; i++) {
        const minerObj = await w3fsStakeManager.storageMiners(i);
        if (minerObj.signer != '0x0000000000000000000000000000000000000000') {
            console.log("miner[", i, "] = ", JSON.stringify(minerObj, null, 5));
        }
    }
}

async function showMinerRewardAndBalance() {
    const accounts = await web3.eth.getAccounts();
    const w3fsStakeManager = await getW3fsStakeManagerContract();
    for (let i = 0; i < 5; i++) {
        const minerObj = await w3fsStakeManager.storageMiners(i);
        if (minerObj.signer != '0x0000000000000000000000000000000000000000') {
            console.log("signer[", minerObj.signer, "] reward = ", web3.utils.fromWei(minerObj.reward.toString(), 'ether'));
            console.log("signer[", minerObj.signer, "] amount = ", web3.utils.fromWei(minerObj.amount.toString(), 'ether'));
            console.log("signer[", minerObj.signer, "] Balance = ", web3.utils.fromWei(await web3.eth.getBalance(minerObj.signer), 'ether'));
        }
    }
}



async function etherTest() {
    const accounts = await web3.eth.getAccounts();
    let currentProvider = new web3.providers.HttpProvider('http://localhost:8545');
    let provider = new ethers.providers.Web3Provider(currentProvider);
    await provider.getBalance(accounts[0]).then(balance => {
        let etherString = ethers.utils.formatEther(balance);
        console.log("Balance: " + etherString);
    });
    let privateKey = '0x2b0e02a259505e91804f8c5f7c02322700f64c1759a1941d0ad32fb8298281f9';
    let wallet = new ethers.Wallet(privateKey, provider);
    let tx = {
        to: "0xb4551baB04854a09b93492bb61b1B011a82cC27A",
        value: ethers.utils.parseEther('2.0')
    }
    // 进行普通转账
    let sendPromise = wallet.sendTransaction(tx);
    await sendPromise.then(tx => {
        console.log(tx);
    });
}

async function TestSlashingManagerTest() {
    const accounts = await web3.eth.getAccounts();
    const slashingManager = await getSlashingManagerContract();
    await slashingManager.slash('0xb4551baB04854a09b93492bb61b1B011a82cC27A').then(function(result,error){
        console.log(result);
        console.log(error)
    });
    await ShowSlashIndicator();
    await TestStakeSprint();
}



async function ShowSlashIndicator() {
    const accounts = await web3.eth.getAccounts();
    const account = '0xCd372b7D1e5c9892d5d545e4b02521AC096F9456';
    const slashingManager = await getSlashingManagerContract();
    const indicator = await slashingManager.indicators(account);
    const result = {
        count : indicator.count.toString(),
        height : indicator.height.toString(),
        totalCount : indicator.totalCount.toString(),
        jailCount : indicator.jailCount.toString(),
        prevAmount : indicator.prevAmount.toString(),
    }
    console.log("[", account, "] = ",JSON.stringify(result, null , 10));
}

async function TestAddValidatorPowerAndProof() {
    const W3fsStorageManager = await getW3fsStorageManager()
    const accounts = await web3.eth.getAccounts();
    const sealData = initRlpData()
    await w3fsStorageManager.addValidatorPowerAndProof(true, accounts[0], 7, sealData).then(function (result, error) {
        console.log(error);
        console.log(result);
    })
}

async function TestCheckSealSigs(){
    const w3fsStorageManager = await getW3fsStorageManager()
    const accounts = await web3.eth.getAccounts();
    const sigs = [
        ['88658294455505865109775093482103872901669787111455695216606631625095742058110','18722145090030161865437419310660999511466097297844657293030239821272530557670','28'],
    ];
    const data = '0x000000000000000000000000b4551bab04854a09b93492bb61b1b011a82cc27a000000000000000000000000000000000000000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000025';

    await w3fsStorageManager.checkSealSigs(data, sigs, {
        from : accounts[0]
    }).then(function(result, error){
        console.log(result)
        console.log(error)
    });
}


module.exports = async function (callback) {
    try {
        // truffle exec scripts/w3fs_test.js --network development
        //await TestStakeTest();
        //await showMinerRewardAndBalance();
        //await TestClaimRewardsMiner();
        //await TestClaimLeaverReward();
        //await showMinerInfo();
        //await TestUnStake();
        //await TestRestake();
        //await getDelegateShareContractByMinerId(1);
        //await showDelegateShareInfo();
        //await etherTest();
        //await TestStakeSprint();
        //await TestBuyVoucher();
        //await TestDelegateWithdrawRewards();
        //await TestSellVoucher();
        //await TestUnstakeClaimTokens();
        //await TestSlashingManagerTest();
        //await TestAddValidatorPowerAndProof();
        //await TestStakeManager01();
        //await TestUnjail();
        //await ShowSlashIndicator();
        //await TestStakeSprint();
        //await TestBuyVoucher();
        await TestCheckSealSigs();
    } catch (e) {
        console.log(e)
    }
    callback()
}
