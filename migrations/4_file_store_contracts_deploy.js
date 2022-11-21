const utils = require('./utils')
const ethUtils = require('ethereumjs-util')

const FileStoreStorageContract = artifacts.require('FileStoreStorage')
const FileStoreLogicContract = artifacts.require('FileStoreLogic')
const FileStoreProxyContract = artifacts.require('FileStoreProxy')

const RegistryContract = artifacts.require('Registry')

const ZeroAddress = '0x0000000000000000000000000000000000000000';

async function getProxyContract(){
    const contractAddresses = utils.getContractAddresses();
    return FileStoreProxyContract.at(contractAddresses.fileStoreProxy);
}

async function getRegistryContract() {
    const contractAddresses = utils.getContractAddresses()
    return RegistryContract.at(contractAddresses.registry);
}

module.exports = async function (deployer, network, accounts) {

    deployer.then(async () => {
        // truffle migrate --network dev_lyh --f 4 --to 4
        const contractAddresses = utils.getContractAddresses();
        console.log("=================deploy FileStoreStorageContract===================")
        const fsc = await deployer.deploy(FileStoreStorageContract); // var fsc not used
        const fsca = await FileStoreStorageContract.deployed();
        console.log("FileStoreStorageContract deployed success | address : ", fsca.address);

        console.log("=================deploy FileStoreLogicContract===================")
        const flc = await deployer.deploy(FileStoreLogicContract);
        const flca = await FileStoreLogicContract.deployed();
        console.log("FileStoreStorageContract deployed sucess | address : ", flca.address);
        const initializeABI = flc.contract.methods.initialize([fsca.address]).encodeABI();
        console.log("initialize's ABI is : ", initializeABI);

        // invoke updateAndCall, execute initialize method.
        const proxy = await getProxyContract();

        await proxy.initialize(accounts[0]).then(function(result){
            console.log(result);
        });

        await proxy.updateAndCall(flca.address,initializeABI).then(function(result,error){
            console.log(result);
        });

        console.log("==================== write contractAddresses ======= ")
        contractAddresses.fileStoreStorage = fsca.address;
        contractAddresses.fileStoreLogic = flca.address;
        utils.writeContractAddresses(contractAddresses);
    })

}
