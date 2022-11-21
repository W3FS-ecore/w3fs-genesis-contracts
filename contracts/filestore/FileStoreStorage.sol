//SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import {FileStoreStruct} from "./UtilsContract.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract FileStoreStorage is Context, Pausable, AccessControl, FileStoreStruct {
	// proxy address
	address private FILE_STORE_PROXY_ADDR = 0x0000000000000000000000000000000000003002;
	// oriHash as key.
	mapping(bytes32 => FileStoreInfo) private fileStoreMapping;
	// entire file storage 's map, storeKeyHash is sha256(file hash + user address)
	mapping(bytes32 => FileStoreInfo) private entireFileStoreMapping;
	// store miner's ip and port. key is minerId
	mapping(bytes32 => MinerInfo) private minerInfoMapping;
	// store relation between address and minerId
	mapping(address => bytes32) private minerAddrIdMapping;
	// store relation between minerId and oriHash
	mapping(address => bytes32[]) private minerFileMapping;
	mapping(address => bytes32[]) private minerEntireFileMapping;

	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

	//540 days
	uint256 private constant fileDuration = 4665600;
	//uint256 private constant fileDuration = 300;

	constructor() public {
		_setupRole(PAUSER_ROLE, _msgSender());
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		withdrawThreshold = 30;
	}

	/**
     * @dev Pauses all transfers.
     *
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
	function pause() external virtual {
		require(hasRole(PAUSER_ROLE, _msgSender()), "FileStoreStorage: must have pauser role to pause");
		_pause();
	}

	/**
     * @dev Unpauses all  transfers.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
	function unpause() external virtual {
		require(hasRole(PAUSER_ROLE, _msgSender()), "FileStoreStorage: must have pauser role to unpause");
		_unpause();
	}

	modifier onlyProxyInvoke {
		//require(msg.sender == FILE_STORE_PROXY_ADDR, "FileStoreStorage: only Proxy can invoke");
		_;
	}

	function createFileStoreInfo4Entire(
		bytes32 storeKeyHash,
		address ownerAddr,
		uint256 fileSize,
		string calldata fileExt,
		bytes32 minerId,
		bytes32 headHash,
		bytes32 bodyHash,
		uint256 operTime,
		uint256 fileCost) external onlyProxyInvoke whenNotPaused(){
		require(storeKeyHash > 0, "storeKeyHash  cannot be empty");
		require(bodyHash == headHash, "bodyHash must equals headHash");
		FileStoreInfo storage fsi = entireFileStoreMapping[storeKeyHash];
		commonCreateFileStore(fsi,storeKeyHash,ownerAddr,fileSize,fileExt,minerId,headHash,bodyHash,operTime,fileCost);
	}

	function createFileStoreInfo(
		bytes32 oriHash,
		address ownerAddr,
		uint256 fileSize,
		string calldata fileExt,
		bytes32 minerId,
		bytes32 headHash,
		bytes32 bodyHash,
		uint256 operTime,
		uint256 fileCost) external onlyProxyInvoke whenNotPaused(){
		require(oriHash > 0, "oriHash  cannot be empty");
		require(headHash > 0, "headHash cannot be empty");
		require(bodyHash > 0, "bodyHash cannot be empty");
		FileStoreInfo storage fsi = fileStoreMapping[oriHash];
		commonCreateFileStore(fsi,oriHash,ownerAddr,fileSize,fileExt,minerId,headHash,bodyHash,operTime,fileCost);
	}

	function commonCreateFileStore(FileStoreInfo storage fsi,
		bytes32 oriHash,
		address ownerAddr,
		uint256 fileSize,
		string memory fileExt,
		bytes32 minerId,
		bytes32 headHash,
		bytes32 bodyHash,
		uint256 operTime,
		uint256 fileCost) internal {
		require(fileSize > 0, "fileSize must greater than 0.");
		require(minerId > 0, "minerId cannot be empty");
		require(operTime > 0, "operTime cannot be empty");
		require(ownerAddr != address(0), "ownerAddr cannot be empty");
		require(fileCost > 0, "fileCost must greater than 0.");
		BaseInfo storage tmp = fsi.baseInfo;
		FileInfo memory fi;
		uint256 expireTime = operTime + fileDuration;
		if (tmp.ownerAddr == address(0)) {
			// first time to create
			tmp.oriHash = oriHash;
			tmp.ownerAddr = ownerAddr;
			tmp.fileSize = fileSize;
			tmp.fileExt = fileExt;
			tmp.cDate = operTime;
			tmp.mDate = operTime;
			// add a miner
			tmp.miners.push(minerId);
			fi = FileInfo(0,headHash,"",0,bodyHash,"",fileCost,Status.Transfer,operTime,operTime, expireTime);
		} else {
			require(tmp.ownerAddr == ownerAddr, "The same oriHash is already used by another user.");
			// Check to see if miners exist
			bool minerExistFlag = _isMinerExist(fsi, minerId);
			require(!minerExistFlag, "the miner was selected before, please change one!");
			// we don't find it,add it.
			tmp.miners.push(minerId);
			fi = FileInfo(0,headHash,"",0,bodyHash,"",fileCost,Status.Transfer,operTime,operTime, expireTime);
		}
        fsi.fileMap[minerId] = fi;
	}

	// for whole file storage
	function updateFileStoreInfo4Entire(
		bytes32 storeKeyHash,
		address minerAddr,
		bool  headFlag,
		string calldata cid,
		uint8 status,
		uint256 operTime
	)
	external onlyProxyInvoke whenNotPaused(){
		require(storeKeyHash > 0, "storeKeyHash  cannot be empty");
		// get info
		FileStoreInfo storage fsi = entireFileStoreMapping[storeKeyHash];
		commonUpdateFileStoreInfo(fsi,storeKeyHash,minerAddr,headFlag,cid,status,operTime);
	}

	// for seperate file storage, include head and body file.
	function updateFileStoreInfo(
		bytes32 oriHash,
		address minerAddr,
		bool  headFlag,
		string calldata cid,
		uint8 status,
		uint256 operTime
	)
	external onlyProxyInvoke whenNotPaused(){
		require(oriHash > 0, "oriHash  cannot be empty");
		// get info
		FileStoreInfo storage fsi = fileStoreMapping[oriHash];
		commonUpdateFileStoreInfo(fsi,oriHash,minerAddr,headFlag,cid,status,operTime);
	}

	function commonUpdateFileStoreInfo(
		FileStoreInfo storage fsi,
		bytes32 oriHash,
		address minerAddr,
		bool  headFlag,
		string memory cid,
		uint8 status,
		uint256 operTime
	) internal {
		require(oriHash > 0, "oriHash  cannot be empty");
		require(minerAddr != address(0), "minerAddr cannot be empty");
		require(bytes(cid).length > 0,"cid  cannot be empty");
		require(status > 0, "status must be greater than 0.");
		BaseInfo storage info = fsi.baseInfo;
		require(info.cDate > 0, "The file storage info not found.");
		info.mDate = operTime;
		// check miner address is correct?
		bytes32 minerId = minerAddrIdMapping[minerAddr];
		require(minerId > 0, "You have not registered information to the chain OR You do not have permission to update");
		FileInfo storage fileInfo = fsi.fileMap[minerId];
		require(fileInfo.cDate > 0, "The miner is not this file's storage provider.");
		fileInfo.mDate = operTime;
		if (headFlag) {
			// update info about the head
			fileInfo.headStatus = status;
			fileInfo.headCid = cid;
		} else {
			// update info about the body
			fileInfo.bodyStatus = status;
			fileInfo.bodyCid = cid;
		}
	}

    // for entire file storage
	function updateFileCostStatus4Entire(
		bytes32 storeKeyHash,
		address minerAddr
	)
	external onlyProxyInvoke whenNotPaused(){
		require(storeKeyHash > 0, "storeKeyHash  cannot be empty");
		// get info
		FileStoreInfo storage fsi = entireFileStoreMapping[storeKeyHash];
		bool ret = commonUpdateFileCostStatus(fsi,minerAddr,StorageType.EntireFile);
		if (ret) {
			minerEntireFileMapping[minerAddr].push(storeKeyHash);
		}
	}

	// for seperate file storage, include head and body file.
	function updateFileCostStatus(
		bytes32 oriHash,
		address minerAddr
	)
	external onlyProxyInvoke whenNotPaused(){
		require(oriHash > 0, "oriHash  cannot be empty");
		// get info
		FileStoreInfo storage fsi = fileStoreMapping[oriHash];
		bool ret = commonUpdateFileCostStatus(fsi,minerAddr,StorageType.SeperateFile);
		if (ret) {
			minerFileMapping[minerAddr].push(oriHash);
		}
	}

	function commonUpdateFileCostStatus(
		FileStoreInfo storage fsi,
		address minerAddr,
		StorageType storageType
	) internal returns(bool) {
		require(minerAddr != address(0), "minerAddr cannot be empty");
		// check miner address is correct?
		bytes32 minerId = minerAddrIdMapping[minerAddr];
		require(minerId > 0, "You have not registered information to the chain OR You do not have permission to update");
		FileInfo storage fileInfo = fsi.fileMap[minerId];
		require(fileInfo.cDate > 0, "The miner is not this file's storage provider.");
		require(fileInfo.fileCostStatus != Status.Locked, "file locked, the operation is not allow");
		require(fileInfo.fileCostStatus == Status.Transfer, "the operation is not allow in current status");
		if (storageType == StorageType.SeperateFile && fileInfo.headStatus == 1 && fileInfo.bodyStatus == 1 ||
			 storageType == StorageType.EntireFile && fileInfo.bodyStatus == 1) {
			fileInfo.fileCostStatus = Status.Withdraw30;
			fileInfo.fileCost -= fileInfo.fileCost * withdrawThreshold / 100;
			return true;
		}
		return false;
	}

	function lockOrUnlock(bytes32 oriHash,
		bytes32 minerId,
		bool isLocked,
		bool isEntireFile
	) external onlyProxyInvoke whenNotPaused(){
		// valid parameters
		require(oriHash > 0, "oriHash cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
        FileInfo storage fileInfo;
		if (!isEntireFile) {
			FileStoreInfo storage fsi = fileStoreMapping[oriHash];
			fileInfo = fsi.fileMap[minerId];
		} else {
			FileStoreInfo storage fsi = entireFileStoreMapping[oriHash];
		    fileInfo = fsi.fileMap[minerId];
		}
		require(!isEntireFile && fileInfo.headStatus == 1 && fileInfo.bodyStatus == 1 ||
			isEntireFile && fileInfo.bodyStatus == 1, "the operation is not allow, file store is in progress");

		require(fileInfo.fileCostStatus == Status.Locked || fileInfo.fileCostStatus == Status.Withdraw30,
	    	"can't lock or unlock, the current status is not allow");

		if (isLocked) {
			fileInfo.fileCostStatus = Status.Locked;
		} else {
			fileInfo.fileCostStatus = Status.Withdraw30;
		}
	}

	// withdraw the balance
    function commonCalcStorageFileCost(bytes32 oriHash,
			bytes32 minerId,
			StorageType storageType
	) external view onlyProxyInvoke whenNotPaused() returns(uint256) {
		require(oriHash > 0, "oriHash  cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
		FileInfo storage fileInfo;
		uint256 fileCost = 0;
		if (storageType == StorageType.SeperateFile) {
			FileStoreInfo storage fsi = fileStoreMapping[oriHash];
			fileInfo = fsi.fileMap[minerId];
		} else {
			FileStoreInfo storage fsi = entireFileStoreMapping[oriHash];
		    fileInfo = fsi.fileMap[minerId];
		}
		require(fileInfo.fileCost > 0, "file cost must greater than zero");
		if (fileInfo.fileCostStatus == Status.Transfer &&
			(fileInfo.headStatus == 1 && fileInfo.bodyStatus == 1 && storageType == StorageType.SeperateFile
			 || storageType == StorageType.EntireFile && fileInfo.bodyStatus == 1)) {
			fileCost = fileInfo.fileCost * withdrawThreshold / 100;
		}
		return fileCost;
	}

	function getExpireFile(address minerAddr) 
		external onlyProxyInvoke whenNotPaused() view returns(ExpireFile memory) {
		//the file in minerFileMapping, must be headStatus==1, bodyStatus==1, fileCostStatus == Status.Withdraw30
		require(minerAddr != address(0), "minerAddr cannot be empty");
		bytes32 minerId = minerAddrIdMapping[minerAddr];
		require(minerId > 0, "the operation is not allow, the miner doesn't register in the chain");
		return commonGetExpireFile(minerId, minerFileMapping[minerAddr], StorageType.SeperateFile);
	}

	function getExpireFileEntire(address minerAddr) 
		external onlyProxyInvoke whenNotPaused() view returns(ExpireFile memory) {
		//the file in minerFileMapping, must be headStatus==1, bodyStatus==1, fileCostStatus == Status.Withdraw30
		require(minerAddr != address(0), "minerAddr cannot be empty");
		bytes32 minerId = minerAddrIdMapping[minerAddr];
		require(minerId > 0, "the operation is not allow, the miner doesn't register in the chain");
		return commonGetExpireFile(minerId, minerEntireFileMapping[minerAddr], StorageType.EntireFile);
	}

	function commonGetExpireFile(bytes32 minerId, bytes32[] storage allFiles, StorageType storageType)
		internal onlyProxyInvoke whenNotPaused() view returns(ExpireFile memory) {
		for (uint i = 0; i < allFiles.length; i++) {
			FileStoreInfo storage fsi;
			if (storageType == StorageType.SeperateFile) {
				fsi = fileStoreMapping[allFiles[i]];
			} else {
				fsi = entireFileStoreMapping[allFiles[i]];
			}
			FileInfo storage fileInfo = fsi.fileMap[minerId];
			if (fileInfo.fileCostStatus == Status.Withdraw30 && block.timestamp > fileInfo.eDate) {
				return ExpireFile(allFiles[i], i, storageType);
			}
		}
		return ExpireFile(0, 0, StorageType.Unknown);
	}

	// withdraw the balance
    function updateRemainingFileCost(address minerAddr, bytes32 oriHash, uint256 index, StorageType storageType)
		external onlyProxyInvoke whenNotPaused() returns(uint256) {
		require(minerAddr != address(0), "minerAddr cannot be empty");
		require(storageType == StorageType.EntireFile || storageType == StorageType.SeperateFile,
			"storageType is invalid");
		bytes32 minerId = minerAddrIdMapping[minerAddr];
		require(minerId > 0, "the operation is not allow, the miner doesn't register in the chain");
    	bytes32[] storage allFiles;
		if (storageType == StorageType.SeperateFile) {
			allFiles = minerFileMapping[minerAddr];
		} else {
			allFiles = minerEntireFileMapping[minerAddr];
		}
		require(index < allFiles.length, "out of array");
		require(oriHash == allFiles[index], "the oriHash is not equal to the Array Index's");
		FileStoreInfo storage fsi;
		if (storageType == StorageType.SeperateFile) {
			fsi = fileStoreMapping[allFiles[index]];
		} else {
			fsi = entireFileStoreMapping[allFiles[index]];
		}
		FileInfo storage fileInfo = fsi.fileMap[minerId];
		require(fileInfo.fileCostStatus == Status.Withdraw30 && block.timestamp > fileInfo.eDate,
			"incorrect status or the file deadline doesn't arrive");
		uint256 fileCost = fileInfo.fileCost;
		fileInfo.fileCost = 0;
		fileInfo.fileCostStatus = Status.Withdraw70;
		allFiles[index] = allFiles[allFiles.length - 1];
		allFiles.pop();

		return fileCost;
	}
	
	// for entire file storage
	function extendFileDeadlineEntire(
		bytes32 storeKeyHash,
		bytes32 minerId,
		uint256 fileCost,
		uint256 fileSize
	)
	external onlyProxyInvoke whenNotPaused() {
		require(storeKeyHash > 0, "storeKeyHash  cannot be empty");
		MinerInfo storage minerInfo = minerInfoMapping[minerId];
		string memory publicKey = minerInfo.publicKey;
		require(bytes(publicKey).length > 0,"The miner you selected does not exist");
		address minerAddr = minerInfo.minerAddr;
		// get info
		FileStoreInfo storage fsi = entireFileStoreMapping[storeKeyHash];
		commonExtendFileDeadline(fsi, minerId, StorageType.EntireFile, fileCost, fileSize);
		bytes32[] storage allEntireFiles = minerEntireFileMapping[minerAddr];
		bool found = false;
		for (uint i = 0; i < allEntireFiles.length; i++) {
			if (storeKeyHash == allEntireFiles[i]) {
				found = true;
				break;
			}
		}
		if (!found) {
			allEntireFiles.push(storeKeyHash);
		}
	}

	// for seperate file storage, include head and body file.
	function extendFileDeadline(
		bytes32 oriHash,
		bytes32 minerId,
		uint256 fileCost,
		uint256 fileSize
	)
	external onlyProxyInvoke whenNotPaused(){
		require(oriHash > 0, "oriHash  cannot be empty");
		MinerInfo storage minerInfo = minerInfoMapping[minerId];
		string memory publicKey = minerInfo.publicKey;
		require(bytes(publicKey).length > 0,"The miner you selected does not exist");
		address minerAddr = minerInfo.minerAddr;
		// get info
		FileStoreInfo storage fsi = fileStoreMapping[oriHash];
		commonExtendFileDeadline(fsi, minerId, StorageType.SeperateFile, fileCost, fileSize);
		bytes32[] storage allFiles = minerFileMapping[minerAddr];
		bool found = false;
		for (uint i = 0; i < allFiles.length; i++) {
			if (oriHash == allFiles[i]) {
				found = true;
				break;
			}
		}
		if (!found) {
			allFiles.push(oriHash);
		}
	}

	function commonExtendFileDeadline(
		FileStoreInfo storage fsi,
		bytes32 minerId,
		StorageType storageType,
		uint256 fileCost,
		uint256 fileSize
	) internal {
		BaseInfo storage info = fsi.baseInfo;
		require(info.cDate > 0, "The file storage info not found.");
		require(fileSize == info.fileSize, "the fileSize is not equal to the previous store file");
		FileInfo storage fileInfo = fsi.fileMap[minerId];
		require(fileInfo.cDate > 0, "The miner is not this file's storage provider.");
		require(fileInfo.fileCostStatus != Status.Locked, "file locked, the operation is not allow");
		require(storageType == StorageType.SeperateFile && fileInfo.headStatus == 1 && fileInfo.bodyStatus == 1 ||
			 storageType == StorageType.EntireFile && fileInfo.bodyStatus == 1, "the operation is not allow in current status");
		fileInfo.fileCostStatus = Status.Withdraw30;
		fileInfo.fileCost += fileCost;
		////the file deadline doesn't arrived
		if (fileInfo.eDate > block.timestamp) {
			fileInfo.eDate += fileDuration;
		} else {
			fileInfo.eDate = block.timestamp + fileDuration;
		}
	}

	function updateWithdrawThreshold(uint256 threshold)
	 external onlyProxyInvoke whenNotPaused(){
		withdrawThreshold = threshold;
	}

	// register dapp contract's Addrress for file when publish order on dapp. only for seperate file storage.
	function regDappContractAddr(
		bytes32 oriHash,
		address ownerAddr,
		address dappContractAddr,
		uint256 operTime
	) external onlyProxyInvoke whenNotPaused(){
		require(oriHash > 0, "oriHash  cannot be empty");
		require(ownerAddr != address(0), "ownerAddr cannot be empty");
		require(dappContractAddr != address(0), "dappContractAddr cannot be empty");
		// get info
		FileStoreInfo storage fsi = fileStoreMapping[oriHash];
		BaseInfo storage info = fsi.baseInfo;
		require(info.cDate > 0, "The file storage info not found.");
		info.dappContractAddrs.push(dappContractAddr);
		info.mDate = operTime;
	}

	// transfer owner for file when file's ownership has changed. only for seperate file storage.
	function transferFileOwner(
		bytes32 oriHash,
		address ownerAddr,
		uint256 operTime
	) external onlyProxyInvoke whenNotPaused(){
		require(oriHash > 0, "oriHash  cannot be empty");
		require(ownerAddr != address(0), "the new ownerAddr cannot be empty");
		// get info
		FileStoreInfo storage fsi = fileStoreMapping[oriHash];
		BaseInfo storage info = fsi.baseInfo;
		require(info.cDate > 0, "The file storage info not found.");
		// change the owner to new owner
		info.ownerAddr = ownerAddr;
		// clear all dapp contract addresses.
		delete info.dappContractAddrs;
		// set the mDate to the lastst time.
		info.mDate = operTime;
	}

	// set miner address and ip/port/publicKey etc.
	function setMinerInfo(bytes32 minerId,address minerAddr, string calldata publicKey
		,string calldata peerId,string calldata peerAddr,string calldata proxyAddr)
	    external onlyProxyInvoke whenNotPaused() {
		require(minerId > 0, "minerId cannot be empty");
		require(minerAddr != address(0), "minerAddr cannot be empty");
		require(bytes(publicKey).length > 0,"publicKey cannot be empty");
		require(bytes(peerId).length > 0,"peerId cannot be empty");
		require(bytes(peerAddr).length > 0,"peerAddr cannot be empty");
		require(bytes(proxyAddr).length > 0,"proxyAddr cannot be empty");
		minerInfoMapping[minerId] = MinerInfo(minerAddr,publicKey,peerId,peerAddr,proxyAddr);
		minerAddrIdMapping[minerAddr] = minerId;
	}

	/**
      Check to see if miners exist
     */
	function isMinerExist(bytes32 oriHash, bytes32 minerId) external view returns(bool) {
		FileStoreInfo memory fsi = fileStoreMapping[oriHash];
		return _isMinerExist(fsi, minerId);
	}

	/**
      Check to see if miners exist for entire file storage
     */
	function isMinerExist4Entire(bytes32 storeKeyHash, bytes32 minerId) external view returns(bool) {
		FileStoreInfo memory fsi = entireFileStoreMapping[storeKeyHash];
		return _isMinerExist(fsi, minerId);
	}

	/**
      Check to see if miners exist
     */
	function _isMinerExist(FileStoreInfo memory fsi, bytes32 minerId) internal pure returns(bool) {
		BaseInfo memory tmp = fsi.baseInfo;
		if (tmp.cDate ==0) {
			return false;
		}
		bool existFlag = false;
		for(uint i = 0; i < tmp.miners.length; i++){
			if (tmp.miners[i] == minerId) {
				existFlag = true;
			}
		}
		return existFlag;
	}

	// get file info for entire file storage
	function getBaseInfo4Entire(bytes32 storeKeyHash) external view returns(BaseInfo memory) {
		FileStoreInfo memory tmp = entireFileStoreMapping[storeKeyHash];
		return tmp.baseInfo;
	}

	function getBaseInfo(bytes32 oriHash) external view returns(BaseInfo memory) {
		FileStoreInfo memory tmp = fileStoreMapping[oriHash];
		return tmp.baseInfo;
	}

	// get file info for entire file storage 
	function getFileInfo4Entire(bytes32 storeKeyHash,bytes32 minerId) external view returns(FileInfo memory) {
		FileStoreInfo storage fsi = entireFileStoreMapping[storeKeyHash];
		return fsi.fileMap[minerId];
	}

	function getFileInfo(bytes32 oriHash,bytes32 minerId) external view returns(FileInfo memory) {
		FileStoreInfo storage fsi = fileStoreMapping[oriHash];
		return fsi.fileMap[minerId];
	}

	function getMinerInfoByMinerId(bytes32 minerId) external view returns(MinerInfo memory) {
		return minerInfoMapping[minerId];
	}

	function getMinerId(address minerAddr) external view returns(bytes32) {
		require(minerAddr != address(0), "minerAddr cannot be empty");
		return minerAddrIdMapping[minerAddr];
	}

	function getMinerInfoByMinerAddr(address minerAddr) external view returns(MinerInfo memory) {
		require(minerAddr != address(0), "minerAddr cannot be empty");
		bytes32 minerId = minerAddrIdMapping[minerAddr];
		if (minerId == 0) {
			return MinerInfo(address(0),"","","","");
		}
		return minerInfoMapping[minerId];
	}

	// get miner's ids who store the given storeKeyHash
	function getStoreMiners4Entire(bytes32 storeKeyHash) external view returns(bytes32[] memory) {
		// valid parameters
		require(storeKeyHash > 0, "storeKeyHash  cannot be empty");
		// get info
		FileStoreInfo storage info = entireFileStoreMapping[storeKeyHash];
		BaseInfo memory baseInfo = info.baseInfo;
		if (baseInfo.cDate ==0) {
			bytes32[] memory empty;
			return empty;
		}
		return baseInfo.miners;
	}

	// get miner's ids who store the given oriHash
	function getStoreMiners(bytes32 oriHash) external view returns(bytes32[] memory) {
		// valid parameters
		require(oriHash > 0, "oriHash  cannot be empty");
		// get info
		FileStoreInfo storage info = fileStoreMapping[oriHash];
		BaseInfo memory baseInfo = info.baseInfo;
		if (baseInfo.cDate ==0) {
			bytes32[] memory empty;
			return empty;
		}
		return baseInfo.miners;
	}
}
