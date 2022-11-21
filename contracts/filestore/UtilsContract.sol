//SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.6.6;

contract FileStoreStruct {

    enum Status {Transfer, Withdraw30, Withdraw70, Locked, Unknown}
    enum StorageType {Unknown, EntireFile, SeperateFile}

    struct FileInfo {
        uint headStatus; // 0-init 1-stored 2-deleted 3-overtime
        bytes32 headHash;
        string headCid;
        uint256 bodyStatus; // 0-init 1-stored 2-deleted 3-overtime
        bytes32 bodyHash;
        string bodyCid;
        uint256 fileCost;  // the cost of this file to store in sector
        Status fileCostStatus; // 0-transfer 1-withdraw30 2-withdraw70 3-locked
        uint256 cDate; // create time
        uint256 mDate; // modify time
        uint256 eDate; // expire time
    }

    struct BaseInfo {
        bytes32 oriHash;
        address ownerAddr;
        uint256 fileSize;
        string fileExt;
        bytes32[] miners;
        address[] dappContractAddrs;
        uint256 cDate; // create time
        uint256 mDate; // modify time
    }

    struct FileStoreInfo {
        BaseInfo baseInfo;
        mapping(bytes32 => FileInfo) fileMap; // minerId as key
    }

    struct MinerInfo {
        address minerAddr;
        string publicKey;
        string peerId;  // for storage p2p
        string peerAddr; // for storage p2p
        string proxyAddr; // ralate proxy multiAddr
    }


    struct FileMinerInfo {
        bytes32 fileHash;
        string fileCid;
        bytes32[] minerIds;
    }

    struct ContractAddr {
        address contractAddr;
        address adminAddr;
        uint256 blockTs; // block timestamp since unix epoch
    }

    struct ExpireFile {
        bytes32 oriHash;
        uint256 index;
        StorageType storageType;
    }

    uint256 withdrawThreshold;
}
