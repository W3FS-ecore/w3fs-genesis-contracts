# genesis-contracts

### precondition

- solc 0.6.6
- node12

### Use

the project use to :

- generate the file genesis.json.
- initialization contracts

### 1. modify validator

```
$ vim validators.js  # Modify bridge miner info
$ vim w3fs_validtor.js  # Modify storage miner info
```

- validators.js : record the initialization of bridge miners. 
- w3fs_validator.js : record the initialization of storage miners.

### 2. generate genesis.json

```
$ sh generate.sh 15001 bridge-15001
```

If executed successfully, you can get the genesis.json file.