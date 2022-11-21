const program = require("commander")
const fs = require("fs")
const nunjucks = require("nunjucks")
const web3 = require("web3")
const w3fsValidators = require("./miner_validators")
const RLP = require('rlp')


function validatorUpdateRlpEncode(validators) {
  let n = validators.length;
  let vals = [];
  for (let i = 0; i < n; i++) {
    vals.push([
      validators[i].signer,
      validators[i].stakeMount,
    ]);
  }
  let pkg = [0x00, vals];
  let result = web3.utils.bytesToHex(RLP.encode(pkg));
  return result.slice(2);
}


// init header.extra
function generateExtradata(validators) {
  let extraVanity = Buffer.alloc(32);
  let validatorsBytes = extraDataSerialize(validators);
  let extraSeal = Buffer.alloc(65);
  return Buffer.concat([extraVanity, validatorsBytes, extraSeal]);
}

function extraDataSerialize(validators) {
  let n = validators.length;
  let arr = [];
  for (let i = 0; i < n; i++) {
    let validator = validators[i];
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.consensusAddr)));
  }
  return Buffer.concat(arr);
}

program.version("0.0.1")
program.option(
  "-o, --output <output-file>",
  "W3fsStakeManager.sol",
  "./contracts/staking/stakeManager/W3fsStakeManager.sol"
)
program.option(
  "-t, --template <template>",
  "W3fsStakeManager template file",
  "./contracts/staking/stakeManager/W3fsStakeManager.template"
)
program.parse(process.argv)

const data = {
  w3fsMinerBytes: validatorUpdateRlpEncode(w3fsValidators)
}
const templateString = fs.readFileSync(program.template).toString()
const resultString = nunjucks.renderString(templateString, data)
fs.writeFileSync(program.output, resultString)
console.log("W3fs miners set file updated.")
