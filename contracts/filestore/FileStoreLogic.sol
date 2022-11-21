//SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./UtilsContract.sol";
import "./FileStoreStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// FileStoreLogic
contract FileStoreLogic is FileStoreStruct, Pausable, AccessControl  {

	FileStoreStorage private fss;

	address private fileStoreStorageAddress;

	bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // 1NEL/GB
    uint256 private constant COST_PER_GB = 1000000000000000000;
	uint256 private constant COST_PER_MB = 1000000000000000;
    // 1GB file size
    uint256 private constant GBYTE = 1000000000;
	uint256 private constant MBYTE = 1000000;

	constructor() public {
	}

	function initialize(address[] calldata _addrs) external {
		// if not has admin Role and fileStoreStorageAddress is not set,It means it's the first time to execute.
		require(fileStoreStorageAddress==address(0) && !hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
			"The initalize method has already been executed and cannot be repeated");
		_setupRole(PAUSER_ROLE, _msgSender());
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		fss = FileStoreStorage(_addrs[0]);
		fileStoreStorageAddress = _addrs[0];
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
		require(hasRole(PAUSER_ROLE, _msgSender()), "FileStoreLogic: must have pauser role to pause");
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
		require(hasRole(PAUSER_ROLE, _msgSender()), "FileStoreLogic: must have pauser role to unpause");
		_unpause();
	}

	function updateWithdrawThreshold(uint256 threshold) external {
		require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "FileStoreLogic: must have admin role to execute");
		require(threshold > 0 && threshold < 100, "threshold must be grater than 0 and less than 100");
		fss.updateWithdrawThreshold(threshold);
	}

	function setFileStoreStorageAddress(address _addr) external {
		require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "FileStoreLogic: must have admin role to execute");
		fss = FileStoreStorage(_addr);
		fileStoreStorageAddress = _addr;
	}

	function lockOrUnlock(bytes32 oriHash,
		bytes32 minerId,
		bool isLocked,
		bool isEntireFile)
	external whenNotPaused() {
		require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "FileStoreLogic: must have admin role to execute");
		bool minerExistFlag = false;
		if (!isEntireFile) {
			minerExistFlag = fss.isMinerExist(oriHash, minerId);
		} else {
			minerExistFlag = fss.isMinerExist4Entire(oriHash, minerId);
		}
		require(minerExistFlag, "msg.sender doesn't exist in the file's miners");
		fss.lockOrUnlock(oriHash, minerId, isLocked, isEntireFile);
	}

	function getFileCost(uint256 fileSize) public pure returns(uint256) {
		require(fileSize > 0, "fileSize must greater than zero");
		uint256 fileCost =  (fileSize + MBYTE -1)/MBYTE * COST_PER_MB;
		return fileCost;
	}

	function withdrawRemaining(bytes32 oriHash, uint256 index, StorageType storageType)
	external whenNotPaused() payable {
		uint256 fileCost = fss.updateRemainingFileCost(msg.sender, oriHash, index, storageType);
		if (fileCost > 0) {
	    	msg.sender.transfer(fileCost);
		}
	}

	function getExpireFile()
		external whenNotPaused() view returns(ExpireFile memory) {
		return fss.getExpireFile(msg.sender);
	}

	function getExpireFileEntire()
		external whenNotPaused() view returns(ExpireFile memory) {
		return fss.getExpireFileEntire(msg.sender);
	}

	function isFileExpireEntire(bytes32 storeKeyHash, bytes32 minerId) external whenNotPaused() view returns(bool) {
	// valid parameters
		require(storeKeyHash > 0, "storeKeyHash  cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
		bool minerExistFlag = fss.isMinerExist4Entire(storeKeyHash, minerId);
		require(minerExistFlag, "minerId doesn't exist in the file's miners");
		// get file info
		FileInfo memory fileInfo = fss.getFileInfo4Entire(storeKeyHash, minerId);
		return fileInfo.eDate < block.timestamp;
	}

	function isFileExpire(bytes32 oriHash, bytes32 minerId) external whenNotPaused() view returns(bool) {
		// valid parameters
		require(oriHash > 0, "oriHash  cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
		bool minerExistFlag = fss.isMinerExist(oriHash, minerId);
		require(minerExistFlag, "minerId doesn't exist in the file's miners");
		// get file info
		FileInfo memory fileInfo = fss.getFileInfo(oriHash,minerId);
		return fileInfo.eDate < block.timestamp;
	}

	function extendFileDeadlineEntire(
		bytes32 storeKeyHash,
		uint256 fileSize,
		bytes32 minerId)
	external whenNotPaused() payable {
		// check minerId if exist?
		bool minerExistFlag = fss.isMinerExist4Entire(storeKeyHash, minerId);
		require(minerExistFlag, "minerId doesn't exist in the file's miners");
		uint256 fileCost = getFileCost(fileSize);
		require(msg.value == fileCost, "fileCost isn't equal to msg.value");
		fss.extendFileDeadlineEntire(storeKeyHash, minerId, fileCost, fileSize);
		payable(address(this)).transfer(msg.value);
	}

	// extendFileDeadline
	function extendFileDeadline(
		bytes32 oriHash,
		uint256 fileSize,
		bytes32 minerId)
	external whenNotPaused() payable {
		// check minerId if exist?
		bool minerExistFlag = fss.isMinerExist(oriHash, minerId);
		require(minerExistFlag, "minerId doesn't exist in the file's miners");
		uint256 fileCost = getFileCost(fileSize);
		require(msg.value == fileCost, "fileCost isn't equal to msg.value");
		fss.extendFileDeadline(oriHash, minerId, fileCost, fileSize);
		payable(address(this)).transfer(msg.value);
	}

	// createFileStoreInfo4Entire only for entire file storage
	function createFileStoreInfo4Entire(
		bytes32 storeKeyHash,
		uint256 fileSize,
		string calldata fileExt,
		bytes32 minerId)
	external whenNotPaused() payable {
		uint256 operTime = block.timestamp;
		address ownerAddr = msg.sender;
		// check minerId if exist?
		MinerInfo memory minerInfo = fss.getMinerInfoByMinerId(minerId);
		require(bytes(minerInfo.publicKey).length > 0,"The miner you selected does not exist");
		bytes32 fileHash = 0;
		uint256 fileCost = getFileCost(fileSize);
		require(msg.value == fileCost, "fileCost isn't equal to msg.value");
		payable(address(this)).transfer(msg.value);
		fss.createFileStoreInfo4Entire(storeKeyHash,ownerAddr,fileSize,fileExt,minerId,fileHash,fileHash,operTime,fileCost);
		emit newFileStoreEvt(
			storeKeyHash, ownerAddr, fileSize, fileExt, minerId, fileHash, fileHash,operTime
		);
	}

	// createFileStoreInfo
	function createFileStoreInfo(
		bytes32 oriHash,
		uint256 fileSize,
		string calldata fileExt,
		bytes32 minerId,
		bytes32 headHash,
		bytes32 bodyHash)
	external whenNotPaused() payable {
		uint256 operTime = block.timestamp;
		address ownerAddr = msg.sender;
		// check minerId if exist?
		MinerInfo memory minerInfo = fss.getMinerInfoByMinerId(minerId);
		require(bytes(minerInfo.publicKey).length > 0,"The miner you selected does not exist");
		uint256 fileCost = getFileCost(fileSize);
		require(msg.value == fileCost, "fileCost isn't equal to msg.value");
		payable(address(this)).transfer(msg.value);
		fss.createFileStoreInfo(oriHash,ownerAddr,fileSize,fileExt,minerId,headHash,bodyHash,operTime,fileCost);
		emit newFileStoreEvt(
			oriHash, ownerAddr, fileSize, fileExt, minerId,headHash, bodyHash,operTime
		);
	}

	// update file storage's status
	function updateFileStoreInfo4Entire(
		bytes32 storeKeyHash,
		string calldata cid,
		uint8 status
	) external whenNotPaused() payable {
		uint256 operTime = block.timestamp;
		address minerAddr = msg.sender;
		bool headFlag = false;
		bytes32 minerId = fss.getMinerId(minerAddr);
		bool minerExistFlag = fss.isMinerExist4Entire(storeKeyHash, minerId);
		require(minerExistFlag, "msg.sender doesn't exist in the file's miners");
		fss.updateFileStoreInfo4Entire(storeKeyHash,minerAddr,headFlag,cid,status,operTime);
		uint256 fileCost = fss.commonCalcStorageFileCost(storeKeyHash,minerId,StorageType.EntireFile);
		//require(fileCost > 0, "fileCost must be greater than zero");
		if (fileCost > 0) {
	    	msg.sender.transfer(fileCost);
		}
		fss.updateFileCostStatus4Entire(storeKeyHash,minerAddr);
		emit fileInfoChangeEvt(
			storeKeyHash,minerId,headFlag,status,cid
		);
	}

	function updateFileStoreInfo(
		bytes32 oriHash,
		bool  headFlag,
		string calldata cid,
		uint8 status
	) external whenNotPaused() payable {
		uint256 operTime = block.timestamp;
		address minerAddr = msg.sender;
		bytes32 minerId = fss.getMinerId(minerAddr);
		bool minerExistFlag = fss.isMinerExist(oriHash, minerId);
		require(minerExistFlag, "msg.sender doesn't exist in the file's miners");
		fss.updateFileStoreInfo(oriHash,minerAddr,headFlag,cid,status,operTime);
		uint256 fileCost = fss.commonCalcStorageFileCost(oriHash,minerId,StorageType.SeperateFile);
		if (fileCost > 0) {
			msg.sender.transfer(fileCost);
		}
		fss.updateFileCostStatus(oriHash,minerAddr);
		emit fileInfoChangeEvt(
			oriHash,minerId,headFlag,status,cid
		);
	}

	// register dapp contract's address for file when publish order on dapp.
	function regDappContractAddr(
		bytes32 oriHash,
		address dappContractAddr
	)  external whenNotPaused() {
		uint256 operTime = block.timestamp;
		address ownerAddr = msg.sender;
		// get base info.
		BaseInfo memory info = fss.getBaseInfo(oriHash);
		require(info.cDate > 0, "The file storage info not found.");
		// check whether the caller is the owner
		require(info.ownerAddr == ownerAddr, "You are not the owner,YOu has no right to register!");
        // check whether has been registered.
		uint len = info.dappContractAddrs.length;
		bool existFlag = false;
		for(uint i = 0; i < len; i++){
			if (info.dappContractAddrs[i] == dappContractAddr) {
				existFlag = true;
				break;
			}
		}
		require(!existFlag, "Has been registered.No need to register again!");
		// call storageContract method
		fss.regDappContractAddr(oriHash,ownerAddr,dappContractAddr, operTime);
		emit registerDappContractAddrEvt(oriHash,ownerAddr,dappContractAddr);
	}

	// transfer owner for file when file's ownership has changed.
	function transferFileOwner(
		bytes32 oriHash,
		address ownerAddr
	) external whenNotPaused() {
		require(oriHash > 0, "oriHash  cannot be empty");
		require(ownerAddr != address(0), "ownerAddr cannot be empty");
		uint256 operTime = block.timestamp;
		// it is a contract address.
		address invoker = msg.sender;
		// get base info.
		BaseInfo memory info = fss.getBaseInfo(oriHash);
		require(info.cDate > 0, "The file storage info not found.");
		address oldOwnerAddr = info.ownerAddr;
		require(oldOwnerAddr != address(0), "old ownerAddr cannot be empty.");
		require(ownerAddr != oldOwnerAddr, "ownerAddr cannot be same as old!");
		// check whether invoker is in  file's dappContractAddrs
		uint len = info.dappContractAddrs.length;
		bool existFlag = false;
		for(uint i = 0; i < len; i++){
			if (info.dappContractAddrs[i] == invoker) {
				existFlag = true;
				break;
			}
		}
		require(existFlag, "You have no right to call this method:Your contract address must be registered first!");
		// have right to update
		fss.transferFileOwner(oriHash, ownerAddr,operTime);
		// send transferOwnerEvt
		emit transferOwnerEvt(oriHash, oldOwnerAddr, ownerAddr);
	}

	function setMinerInfo(
		bytes32 minerId, string calldata publicKey
		,string calldata peerId,string calldata peerAddr,string calldata proxyAddr) external whenNotPaused() {
		address minerAddr = msg.sender;

		MinerInfo memory m = fss.getMinerInfoByMinerId(minerId);
		if (bytes(m.publicKey).length > 0) {
			// if minerId exists before,need check the minerId of minerAddr equals the new minerId.
			bytes32 oldId = fss.getMinerId(minerAddr);
			require(oldId == minerId, "Operation Deny: You do not have permission to update");
		}
	    // call storageContract method 
		fss.setMinerInfo(minerId,minerAddr,publicKey,peerId,peerAddr,proxyAddr);
		emit setMinerEvt(
			minerId,minerAddr,publicKey
		);
	}

	/**
	   find miner for entire file storage
	*/
	function findMiner4EntireFile(bytes32 storeKeyHash) external view returns(FileMinerInfo memory) {
		// valid parameters
		require(storeKeyHash > 0, "storeKeyHash  cannot be empty");
		return commonFindMiner4File(1, storeKeyHash, false);
	}

	/**
	   find miner for file
	*/
	function findMiner4File(bytes32 oriHash, bool headFlag) external view returns(FileMinerInfo memory) {
		// valid parameters
		require(oriHash > 0, "oriHash  cannot be empty");
		
		return commonFindMiner4File(2,oriHash,headFlag);
	}

	/**
	   find miner for file
	*/
	function commonFindMiner4File(uint8 storageType, bytes32 oriHash, bool headFlag) internal view returns(FileMinerInfo memory) {
		// valid parameters
		require(oriHash > 0, "oriHash  cannot be empty");
		// get info
		BaseInfo memory baseInfo;
		if (storageType == 2) {
			baseInfo = fss.getBaseInfo(oriHash);
		} else {
			baseInfo = fss.getBaseInfo4Entire(oriHash);
		}

		uint minerNum = 0;
		for(uint i = 0; i < baseInfo.miners.length; i++){
			bytes32 minerId = baseInfo.miners[i];
			FileInfo memory fileInfo;
			if (storageType == 2) {
				fileInfo = fss.getFileInfo(oriHash,minerId);
			} else {
				fileInfo = fss.getFileInfo4Entire(oriHash,minerId);
			}
			if (headFlag) {
				if (fileInfo.headStatus == 1 && block.timestamp < fileInfo.eDate) {
					minerNum++;
				}
			} else {
				if (fileInfo.bodyStatus == 1 && block.timestamp < fileInfo.eDate) {
					minerNum++;
				}
			}
		}

		bytes32[] memory minerIds = new bytes32[](minerNum);
		FileMinerInfo memory ret = FileMinerInfo(0,"",minerIds);
		if (baseInfo.cDate == 0) {
			return ret;
		}
		// There are no effective miners
		if (minerNum == 0) {
			return ret;
		}
		// loop the miners
		uint index = 0;
		for(uint i = 0; i < baseInfo.miners.length; i++){
			bytes32 minerId = baseInfo.miners[i];
			FileInfo memory fileInfo;
			if (storageType == 2) {
				fileInfo = fss.getFileInfo(oriHash,minerId);
			} else {
				fileInfo = fss.getFileInfo4Entire(oriHash,minerId);
			}
			if (headFlag) {
				// file has stored
				if (fileInfo.headStatus == 1 && block.timestamp < fileInfo.eDate) {
					if (index == 0) {
						ret.fileHash = fileInfo.headHash;
						ret.fileCid = fileInfo.headCid;
					}
					ret.minerIds[index] = minerId;
					index++;
				}
			} else {
				// file has stored
				if (fileInfo.bodyStatus == 1 && block.timestamp < fileInfo.eDate) {
					if (index == 0) {
						ret.fileHash = fileInfo.bodyHash;
						ret.fileCid = fileInfo.bodyCid;
					}
					ret.minerIds[index] = minerId;
					index++;
				}
			}
		}
		return ret;
	}

	/**
	   get file detail info for entire file storage.
	*/
	function getFileInfo4Entire(bytes32 storeKeyHash, bytes32 minerId) external view returns(FileInfo memory) {
		// valid parameters
		require(storeKeyHash > 0, "storeKeyHash  cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
		// get file info
		FileInfo memory fileInfo = fss.getFileInfo4Entire(storeKeyHash, minerId);
		return fileInfo;
	}

	/**
	   get file detail info
	*/
	function getFileInfo(bytes32 oriHash, bytes32 minerId) external view returns(FileInfo memory) {
		// valid parameters
		require(oriHash > 0, "oriHash  cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
		// get file info
		FileInfo memory fileInfo = fss.getFileInfo(oriHash,minerId);
		return fileInfo;
	}

	/**
	   get file store base info for entire file storage
	*/
	function getBaseInfo4Entire(bytes32 storeKeyHash) external view returns(BaseInfo memory) {
		return fss.getBaseInfo4Entire(storeKeyHash);
	}

	/**
	   get file store base info
	*/
	function getBaseInfo(bytes32 oriHash) external view returns(BaseInfo memory) {
		return fss.getBaseInfo(oriHash);
	}


	/**
	   valid file for seperate file storage
	   @return int  0-not found.1-same  2-diff
	*/
	function validFileInfo(
		bytes32 oriHash, bool headFlag,bytes32 minerId,bytes32 fileHash
	) external view returns(uint8) {
		// valid parameters
		require(oriHash > 0, "oriHash  cannot be empty");
		// get info
		BaseInfo memory baseInfo = fss.getBaseInfo(oriHash);
		if (baseInfo.cDate ==0) {
			return 0;
		}
		// check if miner exist
		bool minerExistFlag = fss.isMinerExist(oriHash, minerId);
		if (!minerExistFlag) {
			return 0;
		}
		// valid parameters
		require(oriHash > 0, "oriHash  cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
		require(fileHash > 0, "fileHash cannot be empty");
		if (baseInfo.cDate ==0) {
			return 0;
		}
		
		FileInfo memory fileInfo = fss.getFileInfo(oriHash,minerId);
		if (headFlag) {
			if (fileInfo.headHash == fileHash) {
				return 1;
			}
		} else {
			if (fileInfo.bodyHash == fileHash) {
				return 1;
			}
		}
		return 2;
	}


	/**
	   checkStorage4Entire: check update whether has finished.
	   @return int  0-not found  1-finish  2- unFinish
	*/
	function checkStorage4Entire(bytes32 storeKeyHash, bytes32 minerId) external view returns(uint8) {
		// valid parameters
		require(storeKeyHash > 0, "storeKeyHash  cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
		// get info 
		BaseInfo memory baseInfo = fss.getBaseInfo4Entire(storeKeyHash);
		// check if miner exist
		bool minerExistFlag = fss.isMinerExist4Entire(storeKeyHash, minerId);
		if (!minerExistFlag) {
			return 0;
		}
		return commonCheckStorage(1, baseInfo, storeKeyHash, false,minerId);
	}

	/**
	   checkStorage: check update whether has finished.
	   @return int  0-not found  1-finish  2- unFinish
	*/
	function checkStorage(
		bytes32 oriHash, bool headFlag, bytes32 minerId
	) external view returns(uint8) {
		// valid parameters
		require(oriHash > 0, "oriHash  cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
		// get info 
		BaseInfo memory baseInfo = fss.getBaseInfo(oriHash);
		// check if miner exist
		bool minerExistFlag = fss.isMinerExist(oriHash, minerId);
		if (!minerExistFlag) {
			return 0;
		}
		return commonCheckStorage(2,baseInfo,oriHash,headFlag,minerId);
	}

	/**
	   storageType:  1-entire file  2-seperate
	   commonCheckStorage: check update whether has finished.
	   @return int  0-not found  1-finish  2- unFinish
	*/
	function commonCheckStorage(
		uint8 storageType,
		BaseInfo memory baseInfo,
		bytes32 oriHash, bool headFlag, bytes32 minerId
	) internal view returns(uint8) {
		// valid parameters
		require(oriHash > 0, "oriHash  cannot be empty");
		require(minerId > 0, "minerId cannot be empty");
		if (baseInfo.cDate ==0) {
			return 0;
		}
		
		FileInfo memory fileInfo;
		if (storageType == 2) {
			fileInfo = fss.getFileInfo(oriHash,minerId);
		} else {
			fileInfo = fss.getFileInfo4Entire(oriHash,minerId);
		}
		if (headFlag) {
			if (fileInfo.headStatus == 1) {
				return 1;
			}
		} else {
			if (fileInfo.bodyStatus == 1) {
				return 1;
			}
		}
		return 2;
	}

	// get miner's ids who store the given storeKeyHash
	function getStoreMiners4Entire(bytes32 storeKeyHash) external view returns(bytes32[] memory) {
		return fss.getStoreMiners4Entire(storeKeyHash);
	}

	// get miner's ids who store the given oriHash
	function getStoreMiners(bytes32 oriHash) external view returns(bytes32[] memory) {
		return fss.getStoreMiners(oriHash);
	}

	function getMinerId(address minerAddr) external view returns(bytes32) {
		return fss.getMinerId(minerAddr);
	}

	function getMinerAddr(bytes32 minerId) external view returns(address) {
		MinerInfo memory minerInfo	= fss.getMinerInfoByMinerId(minerId);
		return minerInfo.minerAddr;
	}

	// get miner info by minerId
	function getMinerInfoByMinerId(bytes32 minerId) external view returns(MinerInfo memory) {
		return fss.getMinerInfoByMinerId(minerId);
	}

	// get proxy ip info by minerId
	function getProxyAddrByMinerId(bytes32 minerId) external view returns(string memory) {
		MinerInfo memory minerInfo	= fss.getMinerInfoByMinerId(minerId);
		return minerInfo.proxyAddr;
	}

	event newFileStoreEvt(
		bytes32 oriHash,  // oriHash
		address userAddr,  // user address
		uint256  fileSize,  // fileSize
		string  fileExt,  // fileExt
		bytes32 minerId,  // minerId
		bytes32 headHash,  // headHash
		bytes32 bodyHash,  // bodyHash
		uint256 operTime   // operTime
	);

	event fileInfoChangeEvt(
		bytes32 oriHash, // oriHash
		bytes32 minerId, // minerId
		bool headFlag,    // headFlag
		uint8 status,   // status
		string  cid // cid
	);

	event setMinerEvt(
		bytes32 minerId, // minerId
		address minerAddr,    // minerAddr
		string  publicKey // publicKey
	);

	event registerDappContractAddrEvt(
		bytes32 oriHash, // oriHash
		address ownerAddr,   // owner's address
		address dappContractAddr  // dapp contract address
	);

	event transferOwnerEvt(
		bytes32 oriHash, // oriHash
		address oldOwnerAddr,   // oldOwnerAddr's address
		address newOwnerAddr  // newOwnerAddr's address
	);

	// transfer to contract
    // function transferToContract() payable public {
    //     payable(address(this)).transfer(msg.value);
    // }

    // get the balance of the contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    fallback() external payable {}

    receive() external payable {}
}
