// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../utils/StringHelper.sol";
import "../utils/Administered.sol";

import "./DistrictStaking.sol";
import "./DistrictInfo.sol";

contract ScavengingS2 is Ownable, ReentrancyGuard, Pausable, Administered {
    using StringHelper for string;

    enum PoolType {
        Open,
        Day,
        LPToken
    }

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    address public govTreasury;
    DistrictStaking public districtStaking;
    DistrictInfo public districtInfo;
    address public burnPool;

    uint256 public periodFinish = 0;
    uint256 public periodStart = 0;

    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 120 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;

    mapping(address => uint256) public rewards;

    uint256 public _totalSupply;
    mapping(address => uint256) public _balances;

    mapping(address => uint256) public stakedBlockNumbers;

    PoolType public poolType;
    uint256 public poolValue;
    uint256 public taxRate;
    uint256 public levelLimit;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IERC20 _rewardsToken,
        IERC20 _stakingToken,
        address _govTreasury,
        DistrictStaking _districtStaking,
        DistrictInfo _districtInfo,
        address _burnPool,
        PoolType _poolType,
        uint256 _poolValue,
        uint256 _taxRate,
        uint256 _levelLimit
    ) {
        rewardsToken = _rewardsToken;
        stakingToken = _stakingToken;
        govTreasury = _govTreasury;
        districtStaking = _districtStaking;
        districtInfo = _districtInfo;
        burnPool = _burnPool;
        poolType = _poolType;
        poolValue = _poolValue;
        taxRate = _taxRate;
        levelLimit = _levelLimit;

        periodStart = 9999999999;

        addAdmin(address(this));
    }

    function setContract(
        IERC20 _rewardsToken,
        IERC20 _stakingToken,
        address _govTreasury,
        DistrictStaking _districtStaking,
        DistrictInfo _districtInfo,
        address _burnPool
    ) public onlyOwner {
        rewardsToken = _rewardsToken;
        stakingToken = _stakingToken;
        govTreasury = _govTreasury;
        districtStaking = _districtStaking;
        districtInfo = _districtInfo;
        burnPool = _burnPool;
    }

    function setVariable(
        PoolType _poolType,
        uint256 _poolValue,
        uint256 _taxRate,
        uint256 _levelLimit
    ) public onlyAdmin {
        poolType = _poolType;
        poolValue = _poolValue;
        taxRate = _taxRate;
        levelLimit = _levelLimit;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.number < periodFinish ? block.number : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored + (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account] * ((rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    function getInfo(address account)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 remainBlockNumber;
        if (poolType == PoolType.Day && _balances[account] > 0) {
            uint256 timeLapse = block.number - stakedBlockNumbers[account];
            if (timeLapse > poolValue) {
                remainBlockNumber = 0;
            } else {
                remainBlockNumber = poolValue - timeLapse;
            }
        }

        return (rewardRate, rewardsDuration, _totalSupply, _balances[account], earned(account), remainBlockNumber);
    }

    function getInfo2(address account)
        public
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (checkStakedDistrictLevel(account), taxRate, levelLimit, periodStart, poolValue);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) public {
        require(block.number >= periodStart, "block.number must be greater than equal to periodStart");
        require(amount > 0, "Cannot stake 0");

        if (levelLimit > 0) {
            bool checkLevel = checkStakedDistrictLevel(msg.sender);
            require(checkLevel, "level limit");
        }

        stakePrivate(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        require(poolType == PoolType.Open, "only can withdraw Open Type");
        withdrawPrivate(msg.sender, amount);
    }

    function getReward() public {
        require(poolType == PoolType.Open || poolType == PoolType.LPToken, "only can getReward Open, LPToken Type");
        getRewardPrivate(msg.sender);
    }

    function exit() public {
        require(poolType == PoolType.Day, "only can exit Day Type");

        if (block.number < periodFinish) {
            require(block.number >= stakedBlockNumbers[msg.sender] + poolValue, "lockup period");
        }

        withdrawPrivate(msg.sender, _balances[msg.sender]);
        getRewardPrivate(msg.sender);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 reward) external onlyAdmin updateReward(address(0)) {
        if (block.number >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.number;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance / rewardsDuration, "Provided reward too high");

        lastUpdateTime = block.number;
        periodFinish = periodStart + rewardsDuration;
        emit RewardAdded(reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyAdmin {
        require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint256 _periodStart, uint256 _rewardsDuration) external onlyAdmin {
        rewardsDuration = _rewardsDuration;
        periodStart = _periodStart;

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance / rewardsDuration, "Provided reward too high");

        emit RewardsDurationUpdated(periodStart, rewardsDuration);
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    /* ========== PRIVATE FUNCTIONS ========== */
    function stakePrivate(address account, uint256 amount) private nonReentrant whenNotPaused updateReward(account) {
        stakedBlockNumbers[account] = block.number;

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;

        if (poolType == PoolType.LPToken) {
            stakingToken.transferFrom(account, burnPool, amount);
        } else {
            stakingToken.transferFrom(account, address(this), amount);
        }

        emit Staked(msg.sender, block.number, amount);
    }

    function withdrawPrivate(address account, uint256 amount) private nonReentrant updateReward(account) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply - amount;
        _balances[account] = _balances[account] - amount;

        if (poolType != PoolType.LPToken) {
            stakingToken.transfer(account, amount);
        }

        emit Withdrawn(account, block.number, amount);
    }

    function getRewardPrivate(address account) private nonReentrant updateReward(account) {
        uint256 reward = rewards[account];
        if (reward > 0) {
            rewards[account] = 0;

            uint256 taxAmount = (reward * taxRate) / 100;
            rewardsToken.transfer(address(govTreasury), taxAmount);
            uint256 userAmount = reward - taxAmount;
            rewardsToken.transfer(account, userAmount);

            emit RewardPaid(account, userAmount, taxAmount);
        }
    }

    function checkStakedDistrictLevel(address account) private view returns (bool) {
        bool result;
        uint256[] memory tokenIds = districtStaking.getStakingTokenIds(account);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 level = districtInfo.getAttribute(tokenIds[i], "Level").toInt();
            if (level >= levelLimit) {
                result = true;
                break;
            }
        }

        return result;
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            uint256 oldReward = rewards[account];
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 blockNumber, uint256 amount);
    event Withdrawn(address indexed user, uint256 blockNumber, uint256 amount);
    event RewardPaid(address indexed user, uint256 userAmount, uint256 taxAmount);
    event RewardsDurationUpdated(uint256 periodStart, uint256 newDuration);
    event Recovered(address token, uint256 amount);
    event WithdrawAll(address indexed user, uint256 workCnt);
    event RewardAll(address indexed user, uint256 workCnt);
}
