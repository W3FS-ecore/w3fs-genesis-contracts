const { spawn } = require("child_process")
const program = require("commander")
const nunjucks = require("nunjucks")
const fs = require("fs")
const web3 = require("web3")

//const validators = require("./validators")
const validators = require("./miner_validators")
const utils = require('./migrations/utils')

// load and execute bor validator set
require("./generate-borvalidatorset")

program.version("0.0.1")
program.option("-c, --w3fs-chain-id <w3fs-chain-id>", "W3fs chain id", "15001")
program.option(
  "-o, --output <output-file>",
  "Genesis json file",
  "./genesis.json"
)
program.option(
  "-t, --template <template>",
  "Genesis template json",
  "./genesis-template.json"
)
program.parse(process.argv)

// compile contract
function compileContract(key, contractFile, contractName) {
  return new Promise((resolve, reject) => {
    const ls = spawn("solc", [
      "--bin-runtime",
      "@openzeppelin/=node_modules/@openzeppelin/",
      "solidity-rlp/=node_modules/solidity-rlp/",
      "/=/",
      // "--optimize",
      // "--optimize-runs",
      // "200",
      contractFile
    ])

    const result = []
    ls.stdout.on("data", data => {
      result.push(data.toString())
    })

    ls.stderr.on("data", data => {
      result.push(data.toString())
    })

    ls.on("close", code => {
      console.log(`child process exited with code ${code}`)
      const fn = code === 0 ? resolve : reject
      fn(result.join(""))
    })
  }).then(compiledData => {
    compiledData = compiledData.replace(
      new RegExp(`======= ${contractFile}:${contractName} =======\nBinary of the runtime part:` + '[ ]?'),
      "@@@@"
    )

    const matched = compiledData.match(/@@@@\n([a-f0-9]+)/)
    return { key, compiledData: matched[1], contractName, contractFile }
  })
}


function initContractAddress() {
  const contractAddressesTemplate = utils.getContractAddressesTemple();
  utils.writeContractAddresses(contractAddressesTemplate);
}


// compile files
Promise.all([
  compileContract(
    "borValidatorSetContract",
    "contracts/BorValidatorSet.sol",
    "BorValidatorSet"
  ),
  compileContract(
    "stateReceiverContract",
    "contracts/StateReceiver.sol",
    "StateReceiver"
  ),
  compileContract(
      "registryContract",
      "contracts/common/misc/Registry.sol",
      "Registry"
  ),
  compileContract(
      "mrc20Contract",
      "contracts/mrc20/MRC20.sol",
      "MRC20"
  ),
  compileContract(
    "w3fsStorageManager",
    "contracts/storage/W3fsStorageManager.sol",
    "W3fsStorageManager"
  ),
  compileContract(
      "w3fsStakeManager",
      "contracts/staking/stakeManager/W3fsStakeManager.sol",
      "W3fsStakeManager"
  ),
  compileContract(
      "systemReward",
      "contracts/staking/reward/SystemReward.sol",
      "SystemReward"
  ),
  compileContract(
      "slashingManager",
      "contracts/staking/slashing/SlashingManager.sol",
      "SlashingManager"
  ),
  compileContract(
      "w3fsStakingInfo",
      "contracts/staking/W3fsStakingInfo.sol",
      "W3fsStakingInfo"
  ),

  compileContract(
    "fileStoreProxyContract",
    "contracts/filestore/FileStoreProxy.sol",
    "FileStoreProxy"
  ),
  compileContract(
      "systemRewardContract",
      "contracts/staking/reward/SystemReward.sol",
      "SystemReward"
  )
]).then(result => {

  initContractAddress()

  const totalMaticSupply = web3.utils.toBN("10000000000")

  var validatorsBalance = web3.utils.toBN(0)
  validators.forEach(v => {
    validatorsBalance = validatorsBalance.add(web3.utils.toBN(v.balance))
    v.balance = web3.utils.toHex(web3.utils.toWei(String(v.balance)))
    v.address = v.signer
  })

  const contractBalance = totalMaticSupply.sub(validatorsBalance)
  const data = {
    chainId: program.w3fsChainId,
    validators: validators,
    w3fsChildERC20ContractBalance: web3.utils.toHex(
      web3.utils.toWei(contractBalance.toString())
    )
  }

  result.forEach(r => {
    data[r.key] = r.compiledData
  })

  const templateString = fs.readFileSync(program.template).toString()
  const resultString = nunjucks.renderString(templateString, data)
  fs.writeFileSync(program.output, resultString)
}).catch(err => {
  console.log(err)
  process.exit(1)
})
