const BaseLogicProxy = artifacts.require("BaseLogicProxy");
const BaseLogic = artifacts.require("BaseLogic");
const BaseStore = artifacts.require("BaseStore");
const BaseStoreAddress = '0xfa24F64BC6302F1A2B37BCbbef5B2F510F748eC5';
const BaseLogicAddress = '0x0B17fAe01A15dE5930EC3b350d011BbC796F6dD3';
const BaseLogicProxyAddress = '0x0000000000000000000000000000000000003003';

async function getBaseStoreContract() {
    return BaseStore.at(BaseStoreAddress);
}

async function getBaseLogicContract() {
    return BaseStore.at(BaseLogicAddress);
}

async function getBaseLogicProxyContract() {
    return BaseLogic.at(BaseLogicProxyAddress);
}

async function Test001() {
    const baseLogicContract = await getBaseLogicProxyContract();
    await baseLogicContract.setValueByData(123456).then(function (result, error) {
        console.log(result);
    });
    const baseStoreContract = await getBaseStoreContract();
    const value = await baseStoreContract.value();
    console.log(value);
}

async function Test002() {
}


module.exports = async function (callback) {
    try {
        // truffle exec scripts/proxyTest.js --network dev_53_42
        await Test001();
    } catch (e) {
        console.log(e)
    }
    callback()
}

