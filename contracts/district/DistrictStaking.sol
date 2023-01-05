// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "../utils/ReentrancyGuardByString.sol";
import "../utils/StringHelper.sol";
import "../utils/Administered.sol";

import "./DistrictInfo.sol";
import "./DistrictStaking.sol";

contract DistrictStaking is Ownable, Pausable, ReentrancyGuardByString, Administered {
    using StringHelper for string;
    using StringHelper for uint256;

    struct StakingInfo {
        address owner;
        uint256 tokenId;
        string country;
        uint256 stakedBlockNumber;
        uint256 playBlockNumber;
        uint256 accEarned;
    }

    struct MyStakingInfo {
        uint256 tokenId;
        string city;
        string country;
        uint256 tier;
        uint256 level;
        uint256 stakedBlockNumber;
        uint256 playBlockNumber;
        uint256 remainBlockNumber;
        uint256 accEarned;
    }

    IERC721Enumerable public district;
    DistrictInfo public districtInfo;
    uint256 private waitTime;
    uint256 public startBlockNumber;

    //StakeInfos
    StakingInfo[] public stakedInfos;
    //tokenId => array index
    mapping(uint256 => uint256) private stakedInfoIndexes;
    //tokenId => bool (exist)
    mapping(uint256 => bool) private existStakedInfos;

    //address => tokenId []
    mapping(address => uint256[]) private stakedOwnedTokens;
    //tokenId => array index
    mapping(uint256 => uint256) private stakedOwnedTokensIndexes;

    event Stake(address indexed staker, uint256 indexed tokenId);
    event UnStake(address indexed staker, uint256 indexed tokenId);
    event UnStakeAll(address indexed user, uint256 workCnt);

    constructor(
        IERC721Enumerable _district,
        DistrictInfo _districtInfo,
        uint256 _startBlockNumber
    ) {
        district = _district;
        districtInfo = _districtInfo;
        startBlockNumber = _startBlockNumber;
    }

    function setContract(IERC721Enumerable _district, DistrictInfo _districtInfo) public onlyOwner {
        district = _district;
        districtInfo = _districtInfo;
    }

    function setVariable(uint256 _startBlockNumber) public onlyAdmin {
        startBlockNumber = _startBlockNumber;
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    function stake(uint256 tokenId) public whenNotPaused {
        require(block.number >= startBlockNumber, "start blocknumber");

        require(existStakedInfos[tokenId] == false, "already staked");

        address owner = district.ownerOf(tokenId);

        require(owner == msg.sender, "different owner and msg.sender");

        string memory country = districtInfo.getAttribute(tokenId, "Country");

        addStakingInfo(tokenId, country);

        district.transferFrom(msg.sender, address(this), tokenId);

        emit Stake(msg.sender, tokenId);
    }

    function unStake(uint256 tokenId) public {
        unStake(msg.sender, tokenId);
    }

    function getAllStakeInfos() public view returns (StakingInfo[] memory) {
        return stakedInfos;
    }

    function getStakingInfo(uint256 tokenId) public view returns (StakingInfo memory, bool) {
        StakingInfo memory result;
        bool exist;

        if (existStakedInfos[tokenId] == true) {
            result = stakedInfos[stakedInfoIndexes[tokenId]];
        } else {
            result = StakingInfo({
                owner: address(0),
                tokenId: 0,
                country: "",
                stakedBlockNumber: 0,
                playBlockNumber: 0,
                accEarned: 0
            });
        }

        exist = existStakedInfos[tokenId];
        return (result, exist);
    }

    function unStakeAll(uint256 count) public onlyAdmin {
        uint256 stakedInfoCount = stakedInfos.length;
        uint256 workCnt = stakedInfoCount;

        if (count > 0 && count < stakedInfoCount) {
            workCnt = count;
        }

        for (uint256 i = 0; i < workCnt; i++) {
            unStake(stakedInfos[stakedInfoCount - i - 1].owner, stakedInfos[stakedInfoCount - i - 1].tokenId);
        }

        emit UnStakeAll(msg.sender, workCnt);
    }

    function unStakeAdmin(address owner, uint256 tokenId) public onlyAdmin {
        unStake(owner, tokenId);
    }

    function dice(uint256 tokenId, uint256 earned) public onlyAdmin {
        StakingInfo storage stakingInfo = stakedInfos[stakedInfoIndexes[tokenId]];

        stakingInfo.playBlockNumber = block.number;
        stakingInfo.accEarned = stakingInfo.accEarned + earned;
    }

    function dice(uint256 tokenId) public onlyAdmin {
        StakingInfo storage stakingInfo = stakedInfos[stakedInfoIndexes[tokenId]];

        stakingInfo.playBlockNumber = block.number;
    }

    function earned(uint256 tokenId, uint256 earned) public onlyAdmin {
        StakingInfo storage stakingInfo = stakedInfos[stakedInfoIndexes[tokenId]];
        stakingInfo.accEarned = stakingInfo.accEarned + earned;
    }

    function setWaitTime(uint256 _waitTime) public onlyAdmin {
        waitTime = _waitTime;
    }

    function getMyStakingInfo() public view returns (MyStakingInfo[] memory) {
        uint256 stakingCount = stakedOwnedTokens[msg.sender].length;

        MyStakingInfo[] memory result = new MyStakingInfo[](stakingCount);
        for (uint256 i = 0; i < stakingCount; i++) {
            StakingInfo storage stakingInfo = stakedInfos[stakedInfoIndexes[stakedOwnedTokens[msg.sender][i]]];
            result[i].tokenId = stakingInfo.tokenId;

            result[i].city = districtInfo.getAttribute(stakingInfo.tokenId, "City");
            result[i].country = stakingInfo.country;
            result[i].tier = districtInfo.getAttribute(stakingInfo.tokenId, "Tier").toInt();
            result[i].level = districtInfo.getAttribute(stakingInfo.tokenId, "Level").toInt();
            result[i].stakedBlockNumber = stakingInfo.stakedBlockNumber;
            result[i].playBlockNumber = stakingInfo.playBlockNumber;

            uint256 lastJobBlockNumber;
            if (stakingInfo.stakedBlockNumber > stakingInfo.playBlockNumber) {
                lastJobBlockNumber = stakingInfo.stakedBlockNumber;
            } else {
                lastJobBlockNumber = stakingInfo.playBlockNumber;
            }

            if (block.number >= lastJobBlockNumber + waitTime) {
                result[i].remainBlockNumber = 0;
            } else {
                result[i].remainBlockNumber = lastJobBlockNumber + waitTime - block.number;
            }

            result[i].accEarned = stakingInfo.accEarned;
        }
        return result;
    }

    function getStakingTokenIds(address owner) public view returns (uint256[] memory) {
        return stakedOwnedTokens[owner];
    }

    function getStakingInfos(address owner) public view returns (StakingInfo[] memory) {
        uint256[] memory tokenIds = stakedOwnedTokens[owner];
        StakingInfo[] memory result = new StakingInfo[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            result[i] = stakedInfos[stakedInfoIndexes[tokenIds[i]]];
        }

        return result;
    }

    function getStakingInfos(uint256[] memory tokenIds) public view returns (StakingInfo[] memory) {
        uint256 resultCount;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (existStakedInfos[tokenIds[i]] == true) {
                resultCount++;
            }
        }

        StakingInfo[] memory result = new StakingInfo[](resultCount);

        uint256 index;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (existStakedInfos[tokenIds[i]] == true) {
                result[index] = stakedInfos[stakedInfoIndexes[tokenIds[i]]];
                index++;
            }
        }

        return result;
    }

    function unStake(address account, uint256 tokenId) private {
        require(existStakedInfos[tokenId] == true, "not staked");

        uint256 index = stakedInfoIndexes[tokenId];
        StakingInfo storage info = stakedInfos[index];
        require(info.owner == account, "different owner and msg.sender");

        deleteStakingInfo(tokenId);
        deleteOwnedToken(account, tokenId);

        district.transferFrom(address(this), account, tokenId);

        emit UnStake(account, tokenId);
    }

    function addStakingInfo(uint256 tokenId, string memory country) private {
        stakedInfos.push(
            StakingInfo({
                owner: msg.sender,
                tokenId: tokenId,
                country: country,
                stakedBlockNumber: block.number,
                playBlockNumber: 0,
                accEarned: 0
            })
        );
        stakedInfoIndexes[tokenId] = stakedInfos.length - 1;
        existStakedInfos[tokenId] = true;

        stakedOwnedTokens[msg.sender].push(tokenId);
        stakedOwnedTokensIndexes[tokenId] = stakedOwnedTokens[msg.sender].length - 1;
    }

    function deleteStakingInfo(uint256 tokenId) private {
        uint256 index = stakedInfoIndexes[tokenId];
        uint256 lastIndex = stakedInfos.length - 1;

        if (index != lastIndex) {
            StakingInfo storage temp = stakedInfos[lastIndex];
            stakedInfoIndexes[temp.tokenId] = index;
            stakedInfos[index] = temp;
        }

        stakedInfos.pop();
        delete stakedInfoIndexes[tokenId];
        delete existStakedInfos[tokenId];
    }

    function deleteOwnedToken(address account, uint256 tokenId) private {
        uint256[] storage tokenIds = stakedOwnedTokens[account];
        uint256 index = stakedOwnedTokensIndexes[tokenId];
        uint256 lastIndex = tokenIds.length - 1;

        if (index != lastIndex) {
            uint256 temp = tokenIds[lastIndex];
            stakedOwnedTokensIndexes[temp] = index;
            tokenIds[index] = temp;
        }

        tokenIds.pop();
        delete stakedOwnedTokensIndexes[tokenId];
    }
}
