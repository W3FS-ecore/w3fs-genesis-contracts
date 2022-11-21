const contractAddresses = require('../contractAddresses.json')
const BorValidatorFileCoinPowerContract = artifacts.require('BorValidatorFileCoinPower')
const RegistryContract = artifacts.require('Registry')
const RLP = require('rlp')

async function getBorValidatorFileCoinPowerContract() {
    return BorValidatorFileCoinPowerContract.at(contractAddresses.w3fsStoragePower);
}

async function getRegistryContract(){
    return RegistryContract.at(contractAddresses.registry);
}

function initRlpData(){
    const sealVote = [
        {
            sectorInx : 0x0000000000000000000000000000000000000000,
            sealProofType : 0x0000000000000000000000000000000000000007,
            sealedCID : Buffer.alloc(32),
            proof : Buffer.alloc(32)
        }
    ]
    let n = sealVote.length;
    let vals = [];
    for(let i = 0 ; i < n ; i++) {
        vals.push([
            sealVote[i].sectorInx,
            sealVote[i].sealProofType,
            sealVote[i].sealedCID,
            sealVote[i].proof
        ]);
    }
    return web3.utils.bytesToHex(RLP.encode(vals));
}



async function Test001() {
    const accounts = await web3.eth.getAccounts();
    const borValidatorFileCoinPower = await getBorValidatorFileCoinPowerContract()
    const sealData = initRlpData()
    await borValidatorFileCoinPower.addValidatorPowerAndProof(true, accounts[0], 7, sealData).then(function(result,error){
        console.log(error);
        console.log(result);
    })
    await showInfo()
}

async function showInfo(){
    const accounts = await web3.eth.getAccounts();
    const borValidatorFileCoinPower = await getBorValidatorFileCoinPowerContract()
    console.log("validatorPower = " , (await borValidatorFileCoinPower.getValidatorPower(accounts[0])).toString())
    console.log("validatorNonce = " , (await borValidatorFileCoinPower.validatorNonce(accounts[0])).toString())
    console.log("validatorPromise = " , (await borValidatorFileCoinPower.validatorPromise(accounts[0])).toString())
    console.log("validatorSectorInx = " , (await borValidatorFileCoinPower.getValidatorSectorInx(accounts[0])).toString())
    console.log("validatorStorageSize = ", (await borValidatorFileCoinPower.validatorStorageSize(accounts[0])).toString())
}

module.exports = async function (callback) {
    try {
        // truffle exec scripts/filecoinpower.js --network development
        await Test001()
        await showInfo()
    } catch (e) {
        console.log(e)
    }
    callback()
}

