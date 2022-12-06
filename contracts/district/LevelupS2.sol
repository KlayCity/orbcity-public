// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../utils/StringHelper.sol";
import "../utils/Administered.sol";

import "./DistrictInfo.sol";
import "./DistrictStaking.sol";

contract LevelupS2 is Ownable, Pausable, Administered {
    using StringHelper for string;
    using StringHelper for uint256;

    struct LevelUpCost {
        uint256 lay;
        uint256 orb;
    }

    ERC20Burnable public lay;
    ERC20Burnable public orb;
    DistrictInfo public districtInfo;
    IERC721Enumerable public district;
    DistrictStaking public districtStaking;
    uint256 public startBlockNumber;
    address public communityTreasury;
    uint256 public burnRate;

    mapping(uint256 => uint256) public maxLevels;

    mapping(uint256 => mapping(uint256 => LevelUpCost)) public levelUpCosts;

    event LevelUp(
        address indexed account,
        uint256 indexed tokenId,
        uint256 tier,
        uint256 oldLevel,
        uint256 newLevel,
        uint256 burnLay,
        uint256 burnOrb,
        uint256 communityLay,
        uint256 communityOrb
    );

    event Recovered(address tokenAddress, uint256 tokenAmount);

    constructor(
        DistrictInfo _districtInfo,
        IERC721Enumerable _district,
        DistrictStaking _districtStaking,
        ERC20Burnable _lay,
        ERC20Burnable _orb
    ) {
        districtInfo = _districtInfo;
        district = _district;
        districtStaking = _districtStaking;
        lay = _lay;
        orb = _orb;

        startBlockNumber = 9999999999;
    }

    function setContract(
        DistrictInfo _districtInfo,
        IERC721Enumerable _district,
        DistrictStaking _districtStaking,
        ERC20Burnable _lay,
        ERC20Burnable _orb
    ) public onlyOwner {
        districtInfo = _districtInfo;
        district = _district;
        districtStaking = _districtStaking;
        lay = _lay;
        orb = _orb;
    }

    function setPriceFormula(address _communityTreasury, uint256 _burnRate) public onlyAdmin {
        communityTreasury = _communityTreasury;
        burnRate = _burnRate;
    }

    function setVariable(
        LevelUpCost[] memory oneTierCosts,
        LevelUpCost[] memory twoTierCosts,
        LevelUpCost[] memory threeTierCosts
    ) public onlyAdmin {
        for (uint256 i = 1; i <= 3; i++) {
            for (uint256 j = 1; j <= maxLevels[i]; j++) {
                delete levelUpCosts[i][j];
            }
        }

        for (uint256 i = 1; i <= 3; i++) {
            maxLevels[i] = 0;
        }

        for (uint256 i = 0; i < oneTierCosts.length; i++) {
            uint256 level = i + 1;
            levelUpCosts[1][level] = oneTierCosts[i];
            if (level > maxLevels[1]) {
                maxLevels[1] = level;
            }
        }

        for (uint256 i = 0; i < twoTierCosts.length; i++) {
            uint256 level = i + 1;
            levelUpCosts[2][level] = twoTierCosts[i];
            if (level > maxLevels[2]) {
                maxLevels[2] = level;
            }
        }

        for (uint256 i = 0; i < threeTierCosts.length; i++) {
            uint256 level = i + 1;
            levelUpCosts[3][level] = threeTierCosts[i];
            if (level > maxLevels[3]) {
                maxLevels[3] = level;
            }
        }
    }

    function setStartBlockNumber(uint256 _startBlockNumber) public onlyAdmin {
        startBlockNumber = _startBlockNumber;
    }

    function recoverKIP7(address tokenAddress, uint256 tokenAmount) external onlyAdmin {
        ERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    function levelUp(uint256 tokenId) public whenNotPaused {
        require(burnRate > 0, "no burn rate");

        require(block.number >= startBlockNumber, "start blocknumber");

        address tokenOwner = district.ownerOf(tokenId);
        (DistrictStaking.StakingInfo memory stakingInfo, bool exist) = districtStaking.getStakingInfo(tokenId);
        require(tokenOwner == msg.sender || stakingInfo.owner == msg.sender, "the token is not yours");

        uint256 oldLevel = districtInfo.getAttribute(tokenId, "Level").toInt();
        uint256 tier = districtInfo.getAttribute(tokenId, "Tier").toInt();

        require(tier == 1 || tier == 2 || tier == 3, "tier must be 1, 2, 3");

        uint256 maxLevel = maxLevels[tier];
        require(oldLevel <= maxLevel, "the token is max level");

        LevelUpCost storage cost = levelUpCosts[tier][oldLevel];

        require(cost.lay > 0 || cost.orb > 0, "no levelup cost");

        uint256 burnLay = (cost.lay * burnRate) / 100;
        uint256 burnOrb = (cost.orb * burnRate) / 100;

        lay.burnFrom(msg.sender, burnLay);
        orb.burnFrom(msg.sender, burnOrb);

        uint256 communityTreasuryLay = cost.lay - burnLay;
        uint256 communityTreasuryOrb = cost.orb - burnOrb;

        lay.transferFrom(msg.sender, communityTreasury, communityTreasuryLay);
        orb.transferFrom(msg.sender, communityTreasury, communityTreasuryOrb);

        uint256 newLevel = oldLevel + 1;
        districtInfo.setAttribute(tokenId, "Level", newLevel.toString());

        emit LevelUp(
            msg.sender,
            tokenId,
            tier,
            oldLevel,
            newLevel,
            burnLay,
            burnOrb,
            communityTreasuryLay,
            communityTreasuryOrb
        );
    }

    function getCosts()
        public
        view
        returns (
            LevelUpCost[] memory oneTier,
            LevelUpCost[] memory twoTier,
            LevelUpCost[] memory threeTier
        )
    {
        oneTier = getCosts(1);
        twoTier = getCosts(2);
        threeTier = getCosts(3);
    }

    function getCosts(uint256 tier) private view returns (LevelUpCost[] memory) {
        require(tier == 1 || tier == 2 || tier == 3, "tier must be 1, 2, 3");
        uint256 maxLevel = maxLevels[tier];

        LevelUpCost[] memory result = new LevelUpCost[](maxLevel);
        for (uint256 i = 1; i <= maxLevel; i++) {
            result[i - 1] = levelUpCosts[tier][i];
        }

        return result;
    }
}
