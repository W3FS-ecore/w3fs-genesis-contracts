const utils = require('../migrations/utils')
const contractAddresses = require('../contractAddresses.json')
const ethUtils = require('ethereumjs-util')
const BN = ethUtils.BN
const FileStoreStorageContract = artifacts.require('FileStoreStorage')
const FileStoreLogicContract = artifacts.require('FileStoreLogic')
const FileStoreProxyContract = artifacts.require('FileStoreProxy')

async function getProxyContract(){
    const contractAddresses = utils.getContractAddresses();
    console.log("proxyAddress:", contractAddresses.fileStoreProxy);
    return FileStoreProxyContract.at(contractAddresses.fileStoreProxy);
}

async function getLogicProxy(){
     const contractAddresses = utils.getContractAddresses();
    console.log("getLogicProxy --> proxyAddress:", contractAddresses.fileStoreProxy);
    return FileStoreLogicContract.at(contractAddresses.fileStoreProxy);
}


async function getRegistryContract() {
    const contractAddresses = utils.getContractAddresses()
    return RegistryContract.at(contractAddresses.registry);
}

async function Test003(){
    const logicWithProxy = await getLogicProxy();
    var nodeInfo = utils.getNodeInfo();
    console.log(nodeInfo);
    var nodeId = "0x"+nodeInfo.id;
    console.log(nodeId);
    var enode = nodeInfo.enode;
    console.log(enode);
    const oriHash = 1;
    const fileSize = 100;
    // no need to change.
    const fileHash = "8058982981979900438406189897774802837761417004862174133853862294200276760721";
    //hash = 4;
    console.log("start to run createFileStoreInfo....");
    await logicWithProxy.createFileStoreInfo(oriHash,fileSize,nodeId, fileHash, fileHash).then(function(result,error){
        console.log(result);
        console.log(error);
    });
}


module.exports = async function (callback) {
    try {
        // truffle exec scripts/filestoretest.js --network dev_lyh
        await Test003();
    } catch (e) {
        console.log(e)
    }
    callback()
}

