// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "../utils/Administered.sol";
import "../utils/StringHelper.sol";
import "../utils/ReentrancyGuardByAddress.sol";

import "./DistrictInfo.sol";
import "./DistrictStaking.sol";

contract DiceGameS2 is Ownable, Administered, Pausable, ReentrancyGuardByAddress {
    using StringHelper for string;
    using StringHelper for uint256;

    IERC20 public lay;
    IERC721Enumerable public district;
    DistrictInfo public districtInfo;
    address public govTreasury;
    DistrictStaking public districtStaking;

    // tier => reward
    mapping(uint256 => uint256) public tierReward;

    // level => multiply (ex 50%, 100%)
    mapping(uint256 => uint256) public levelMultiply;

    uint256 public maxLevel;
    uint256 public minTier;

    uint256 public taxRate;
    uint256 public waitTime;
    uint256 public startBlockNumber;

    event GetLays(address indexed user, uint256[] tokenId, uint256 earn, uint256 tax);

    constructor(
        IERC20 _lay,
        IERC721Enumerable _district,
        DistrictInfo _districtInfo,
        address _govTreasury,
        DistrictStaking _districtStaking
    ) {
        lay = _lay;
        district = _district;
        districtInfo = _districtInfo;
        govTreasury = _govTreasury;
        districtStaking = _districtStaking;

        taxRate = 20;
        startBlockNumber = 0;
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
        }

        emit GetLays(msg.sender, tokenIds, userRewards, treasuryRewards);
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
