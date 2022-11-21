#!/usr/bin/env sh

# Usage:
# generate.sh 15001 heimdall-15001

#set -x #echo on
if [ -z "$1" -o -z "$2" ]
  then
    echo "usage:sh $0 [w3fs-chain-id] [bridge-chain-id]"
  exit 1
fi

npm install
node generate-chainIdMixin.js --w3fs-chain-id $1
node generate-borvalidatorset.js --w3fs-chain-id $1 --bridge-chain-id $2
node generate-w3fsvalidatorset.js
npm run truffle:compile
node generate-genesis.js --w3fs-chain-id $1
