// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "../utils/Administered.sol";
import "../utils/StringHelper.sol";
import "../utils/ReentrancyGuardByAddress.sol";

import "../utils/Withdrawable.sol";
import "./DistrictInfo.sol";
import "./DistrictStaking.sol";

contract DiceGameS3 is Ownable, Pausable, ReentrancyGuardByAddress, Withdrawable {
    using StringHelper for string;
    using StringHelper for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct PlayInfo {
        uint256 tokenId;
        address owner;
        address player;
        uint256 blockNumber;
        string blockHash;
        uint256 txCount;
        uint256 ownerReward;
        uint256 paybackReward;
        uint256 playerReward;
        uint256 treasuryReward;
        uint256 bunnerToken;
        bool processed;
        bytes32 hashs;
    }

    IERC20 public lay;
    IERC20 public burner;
    IERC721Enumerable public district;
    DistrictInfo public districtInfo;
    address public govTreasury;
    DistrictStaking public districtStaking;

    // tier => reward
    mapping(uint256 => uint256) public tierReward;

    // level => multiply (ex 50%, 100%)
    mapping(uint256 => uint256) public levelMultiply;

    PlayInfo[] waitPlayInfos;

    mapping(address => PlayInfo[]) playInfoHistories;

    uint256 public maxLevel;
    uint256 public minTier;

    uint256 public taxRate;
    uint256 public paybackRate = 5;
    uint256 public playRate = 5;
    uint256 public burnerRewardCount = 1e18;
    uint256 public waitTime;
    uint256 public startBlockNumber;

    event GetLays(address indexed user, uint256[] tokenId, uint256 earn, uint256 tax);
    event GetLay(
        address indexed owner,
        address indexed player,
        uint256 tokenId,
        uint256 ownerReward,
        uint256 paybackReward,
        uint256 playerReward,
        uint256 tax,
        uint256 bunnerToken
    );

    constructor(
        IERC20 _lay,
        IERC20 _burner,
        IERC721Enumerable _district,
        DistrictInfo _districtInfo,
        address _govTreasury,
        DistrictStaking _districtStaking
    ) {
        lay = _lay;
        burner = _burner;
        district = _district;
        districtInfo = _districtInfo;
        govTreasury = _govTreasury;
        districtStaking = _districtStaking;

        taxRate = 20;
        startBlockNumber = 0;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(WITHDRAWER_ROLE, _msgSender());
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Restricted to admins.");
        _;
    }

    function isAdmin(address account) public view virtual returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function setContract(
        IERC20 _lay,
        IERC721Enumerable _district,
        DistrictInfo _districtInfo,
        address _govTreasury,
        DistrictStaking _districtStaking
    ) public onlyOwner {
        lay = _lay;
        district = _district;
        districtInfo = _districtInfo;
        govTreasury = _govTreasury;
        districtStaking = _districtStaking;
    }

    function setReward(
        uint256[] memory tiers,
        uint256[] memory rewards,
        uint256[] memory levels,
        uint256[] memory multiplies
    ) public onlyAdmin {
        require(tiers.length == rewards.length, "its different tiers and rewards count");
        require(levels.length == multiplies.length, "its different levels and multiplies count");

        // tier => reward
        for (uint256 i = 0; i < tiers.length; i++) {
            tierReward[tiers[i]] = rewards[i];
            if (tiers[i] > minTier) {
                minTier = tiers[i];
            }
        }

        // tier => reward
        for (uint256 i = 0; i < levels.length; i++) {
            levelMultiply[levels[i]] = multiplies[i];
            if (levels[i] > maxLevel) {
                maxLevel = levels[i];
            }
        }
    }

    function setTaxRate(uint256 rate) public onlyAdmin {
        taxRate = rate;
    }

    function setWaitTime(uint256 _waitTime) public onlyAdmin {
        waitTime = _waitTime;
        districtStaking.setWaitTime(waitTime);
    }

    function setStartBlockNumber(uint256 _startBlockNumber) public onlyAdmin {
        startBlockNumber = _startBlockNumber;
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    function getLays(uint256[] memory tokenIds) public whenNotPaused nonReentrantAddress(msg.sender) {
        require(block.number >= startBlockNumber, "start blocknumber");

        uint256 userRewards;
        uint256 treasuryRewards;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            (uint256 userReward, uint256 treasuryReward) = getLay(msg.sender, tokenIds[i]);

            userRewards = userRewards + userReward;
            treasuryRewards = treasuryRewards + treasuryReward;

            emit GetLay(msg.sender, address(0), tokenIds[i], userReward, 0, 0, treasuryReward, 0);
        }

        //     emit GetLays(msg.sender, tokenIds, userRewards, treasuryRewards);
    }

    function getLay(address account, uint256 tokenId) private returns (uint256, uint256) {
        (DistrictStaking.StakingInfo memory stakingInfo, bool exist) = districtStaking.getStakingInfo(tokenId);

        require(exist == true, "no stakeing info");
        require(stakingInfo.owner == account, "this is not your district");

        require(block.number >= stakingInfo.stakedBlockNumber + waitTime, "need to wait for one day after staking");
        require(block.number >= stakingInfo.playBlockNumber + waitTime, "need to wait for one day after playing");

        uint256 level = districtInfo.getAttribute(tokenId, "Level").toInt();

        uint256 tier = districtInfo.getAttribute(tokenId, "Tier").toInt();

        uint256 reward = tierReward[tier] + ((tierReward[tier] * levelMultiply[level]) / 100);

        require(lay.balanceOf(address(this)) >= reward, "not enough lay balance this contract");

        uint256 treasuryReward = (reward * taxRate) / 100;
        uint256 userReward = reward - treasuryReward;

        lay.transfer(account, userReward);
        lay.transfer(govTreasury, treasuryReward);

        districtStaking.dice(tokenId, userReward);

        return (userReward, treasuryReward);
    }

    function tryGetLay(uint256 tokenId, address account) private {
        (DistrictStaking.StakingInfo memory stakingInfo, bool exist) = districtStaking.getStakingInfo(tokenId);

        require(exist == true, "no stakeing info");
        require(stakingInfo.owner != account, "this is your district");

        require(block.number >= stakingInfo.stakedBlockNumber + waitTime, "need to wait for one day after staking");
        require(block.number >= stakingInfo.playBlockNumber + waitTime, "need to wait for one day after playing");

        uint256 level = districtInfo.getAttribute(tokenId, "Level").toInt();
        uint256 tier = districtInfo.getAttribute(tokenId, "Tier").toInt();
        uint256 reward = tierReward[tier] + ((tierReward[tier] * levelMultiply[level]) / 100);

        require(lay.balanceOf(address(this)) >= reward, "not enough lay balance this contract");

        uint256 treasuryReward = (reward * taxRate) / 100;
        uint256 paybackReward = (reward * paybackRate) / 100;
        uint256 playerReward = (reward * playRate) / 100;

        uint256 ownerReward = reward - treasuryReward;
        treasuryReward = treasuryReward - paybackReward - playerReward;

        districtStaking.dice(tokenId);

        waitPlayInfos.push(
            PlayInfo({
                tokenId: tokenId,
                owner: stakingInfo.owner,
                player: account,
                blockNumber: block.number + 1,
                blockHash: "",
                txCount: 0,
                ownerReward: ownerReward,
                paybackReward: paybackReward,
                playerReward: playerReward,
                treasuryReward: treasuryReward,
                bunnerToken: 0,
                processed: false,
                hashs: ""
            })
        );
    }

    function tryGetLayImmediately(uint256 tokenId) public {
        tryGetLayImmediately(tokenId, _msgSender());
    }

    function tryGetLayImmediatelyAdmin(uint256 tokenId, address account) public onlyAdmin {
        tryGetLayImmediately(tokenId, account);
    }

    function tryGetLayImmediately(uint256 tokenId, address account) private {
        (DistrictStaking.StakingInfo memory stakingInfo, bool exist) = districtStaking.getStakingInfo(tokenId);

        require(exist == true, "no stakeing info");
        require(stakingInfo.owner != account, "this is your district");

        require(block.number >= stakingInfo.stakedBlockNumber + waitTime, "need to wait for one day after staking");
        require(block.number >= stakingInfo.playBlockNumber + waitTime, "need to wait for one day after playing");

        uint256 level = districtInfo.getAttribute(tokenId, "Level").toInt();
        uint256 tier = districtInfo.getAttribute(tokenId, "Tier").toInt();
        uint256 reward = tierReward[tier] + ((tierReward[tier] * levelMultiply[level]) / 100);

        require(lay.balanceOf(address(this)) >= reward, "not enough lay balance this contract");

        uint256 treasuryReward = (reward * taxRate) / 100;
        uint256 paybackReward = (reward * paybackRate) / 100;
        uint256 playerReward = (reward * playRate) / 100;

        uint256 ownerReward = reward - treasuryReward;
        treasuryReward = treasuryReward - paybackReward - playerReward;

        uint256 ret = seedCalcNow();

        if (ret > 80) {
            lay.transfer(stakingInfo.owner, ownerReward + paybackReward);
            lay.transfer(account, playerReward);
            lay.transfer(govTreasury, treasuryReward);

            districtStaking.earned(tokenId, ownerReward + paybackReward);
            emit GetLay(
                stakingInfo.owner,
                account,
                tokenId,
                ownerReward,
                paybackReward,
                playerReward,
                treasuryReward,
                0
            );
        } else {
            lay.transfer(stakingInfo.owner, ownerReward);
            lay.transfer(govTreasury, treasuryReward + paybackReward + playerReward);
            burner.transfer(account, burnerRewardCount);

            districtStaking.earned(tokenId, ownerReward);
            emit GetLay(
                stakingInfo.owner,
                account,
                tokenId,
                ownerReward,
                0,
                0,
                paybackReward + playerReward + treasuryReward,
                burnerRewardCount
            );
        }
    }

    function test() public {
        waitPlayInfos.push(
            PlayInfo({
                tokenId: 0,
                owner: _msgSender(),
                player: _msgSender(),
                blockNumber: block.number,
                blockHash: string(abi.encodePacked(blockhash(block.number - 1))),
                txCount: 0,
                ownerReward: 0,
                paybackReward: 0,
                playerReward: 0,
                treasuryReward: 0,
                bunnerToken: 0,
                processed: false,
                hashs: blockhash(block.number - 1)
            })
        );
    }

    function getPlayInfos() public view returns (PlayInfo[] memory) {
        return waitPlayInfos;
    }

    function getPlayInfo(uint256 index) public view returns (PlayInfo memory) {
        return waitPlayInfos[index];
    }

    function tryGetLayAdmin(uint256 tokenId, address account) public onlyAdmin {
        tryGetLay(tokenId, account);
    }

    function tryGetLay(uint256 tokenId) public returns (uint256, uint256) {
        tryGetLay(tokenId, _msgSender());
    }

    function seedCalc(string memory blockHash, uint256 txCount) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(txCount, blockHash))) % 100;
    }

    function seedCalcNow() public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_msgSender(), blockhash(block.number - 1), block.coinbase))) % 100;
    }

    function hash(uint256 txCount) public view returns (bytes32) {
        return blockhash(block.number);
    }

    function play(
        uint256 index,
        uint256 blockNumber,
        string memory blockHash,
        uint256 txCount
    ) public onlyAdmin {
        require(waitPlayInfos.length > index);
        PlayInfo storage player = waitPlayInfos[index];
        require(player.blockNumber == blockNumber);
        require(player.processed == false);

        player.processed = true;
        player.blockHash = blockHash;
        player.txCount = txCount;

        uint256 seed = uint256(keccak256(abi.encodePacked(player.txCount, player.blockHash)));
        uint256 ret = seedCalc(blockHash, txCount);

        if (ret > 80) {
            lay.transfer(player.owner, player.ownerReward + player.paybackReward);
            lay.transfer(player.player, player.playerReward);
            lay.transfer(govTreasury, player.treasuryReward);

            districtStaking.earned(player.tokenId, player.ownerReward + player.paybackReward);
            emit GetLay(
                player.owner,
                player.player,
                player.tokenId,
                player.ownerReward,
                player.paybackReward,
                player.playerReward,
                player.treasuryReward,
                0
            );
        } else {
            lay.transfer(player.owner, player.ownerReward);
            lay.transfer(govTreasury, player.treasuryReward + player.paybackReward + player.playerReward);
            burner.transfer(player.player, burnerRewardCount);

            districtStaking.earned(player.tokenId, player.ownerReward);
            emit GetLay(
                player.owner,
                player.player,
                player.tokenId,
                player.ownerReward,
                0,
                0,
                player.paybackReward + player.playerReward + player.treasuryReward,
                burnerRewardCount
            );
        }
    }

    function emergencyWithdraw(address guardian) public onlyAdmin {
        lay.transfer(guardian, lay.balanceOf(address(this)));
    }

    function getReward() public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory resultTierReward = new uint256[](minTier);
        uint256[] memory resultLevelMultiply = new uint256[](maxLevel);

        for (uint256 i = 1; i <= minTier; i++) {
            resultTierReward[i - 1] = tierReward[i];
        }

        for (uint256 i = 1; i <= maxLevel; i++) {
            resultLevelMultiply[i - 1] = levelMultiply[i];
        }

        return (resultTierReward, resultLevelMultiply);
    }
}
