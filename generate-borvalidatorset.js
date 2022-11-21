const program = require("commander")
const fs = require("fs")
const nunjucks = require("nunjucks")
const web3 = require("web3")
const validators = require("./validators")

program.version("0.0.1")
program.option("--w3fs-chain-id <w3fs-chain-id>", "W3fs chain id", "15001")
program.option(
  "--bridge-chain-id <bridge-chain-id>",
  "Bridge chain id",
  "bridge-P5rXwg"
)
program.option(
  "--first-end-block <first-end-block>",
  "End block for first span",
  "255"
)
program.option(
  "-o, --output <output-file>",
  "BorValidatorSet.sol",
  "./contracts/BorValidatorSet.sol"
)
program.option(
  "-t, --template <template>",
  "BorValidatorSet template file",
  "./contracts/BorValidatorSet.template"
)
program.parse(process.argv)

// process validators
validators.forEach(v => {
  v.address = web3.utils.toChecksumAddress(v.address)
})

const data = {
  w3fsChainId: program.w3fsChainId,
  bridgeChainId: program.bridgeChainId,
  firstEndBlock: program.firstEndBlock,
  validators: validators
}
const templateString = fs.readFileSync(program.template).toString()
const resultString = nunjucks.renderString(templateString, data)
fs.writeFileSync(program.output, resultString)
console.log("Bor validator set file updated.")
