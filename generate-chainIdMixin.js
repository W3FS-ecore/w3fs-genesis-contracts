const program = require("commander")
const fs = require("fs")
const nunjucks = require("nunjucks")
const web3 = require("web3")

program.version("0.0.1")
program.option("--w3fs-chain-id <w3fs-chain-id>", "W3fs chain id", "15001")
/*program.option(
    "--bridge-chain-id <heimdall-chain-id>",
    "Bridge chain id",
    "Bridge-P5rXwg"
)*/
program.option(
    "-o, --output <output-file>",
    "ChainIdMixin.sol",
    "./contracts/mrc20/ChainIdMixin.sol"
)
program.option(
    "-t, --template <template>",
    "ChainIdMixin template file",
    "./contracts/mrc20/ChainIdMixin.sol.template"
)
program.parse(process.argv)


const w3fsChainIdHex = parseInt(program.w3fsChainId, 10)
    .toString(16)
    .toUpperCase();

const data = {
    w3fsChainId: program.w3fsChainId,
    //bridgeChainId: program.bridgeChainId,
    w3fsChainIdHex:
        w3fsChainIdHex.length % 2 !== 0 ? `0${w3fsChainIdHex}` : w3fsChainIdHex
}
const templateString = fs.readFileSync(program.template).toString()
const resultString = nunjucks.renderString(templateString, data)
fs.writeFileSync(program.output, resultString)
console.log("W3fs validator set file updated.")
