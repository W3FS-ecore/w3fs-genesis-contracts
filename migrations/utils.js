const fs = require('fs')
const EthUtil = require('ethereumjs-util')

module.exports = {
  getContractAddresses: () => {
    try {
      return JSON.parse(fs.readFileSync(`${process.cwd()}/contractAddresses.json`).toString())
    } catch (e) {
      return {
        root: {},
        child: {}
      }
    }
  },
  writeContractAddresses: (contractAddresses) => {
    fs.writeFileSync(
      `${process.cwd()}/contractAddresses.json`,
      JSON.stringify(contractAddresses, null, 2) // Indent 2 spaces
    )
  },
  getContractAddressesTemple: () => {
    try {
      return JSON.parse(fs.readFileSync(`${process.cwd()}/contractAddresses-template.json`).toString())
    } catch (e) {
      return {
        root: {},
        child: {}
      }
    }
  },


  getNodeInfo: () => {
    try {
      return JSON.parse(fs.readFileSync(`${process.cwd()}/nodeInfo.json`).toString())
    } catch (e) {
      return {
        root: {},
        child: {}
      }
    }
  },

  privToPub : (private_key) => {
    const e_toBuffer = EthUtil.toBuffer(private_key);
    const e_privateToPublic = EthUtil.privateToPublic(e_toBuffer);
    const pubKey = EthUtil.bufferToHex(e_privateToPublic);
    return pubKey;
  }


}
