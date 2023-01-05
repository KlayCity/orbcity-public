// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../utils/TokenHelper.sol";
import "../utils/Withdrawable.sol";

contract TokenStake is Ownable, Pausable, TokenHelper, Withdrawable {
    struct Info {
        address account;
        uint256 amounts;
        uint256 claimed;
        uint256 claimable;
        uint256 claimBlock;
        uint256 lockedUntil;
    }

    address public immutable stakeToken;
    address public immutable interestToken;
    uint256 public interestRate = 10;
    uint256 public unstakeLock = 2592000;
    string public name;

    mapping(address => Info) public StakeMap;
    mapping(address => uint256) public StakeIndexes;
    address[] public StakeArray;

    event Stake(address indexed staker, uint256 amounts, uint256 total);
    event Unstake(address indexed staker, uint256 amounts, uint256 total);
    event Claim(address indexed account, uint256 amounts, uint256 total);

    constructor(
        string memory _name,
        address _stakeToken,
        address _interestToken
    ) {
        name = _name;
        stakeToken = _stakeToken;
        interestToken = _interestToken;
        _setupRole(WITHDRAWER_ROLE, _msgSender());
    }

    function setUnstakeLock(uint256 value) public onlyOwner {
        unstakeLock = value;
    }

    function setInterestRate(uint256 value) public onlyOwner {
        interestRate = value;
    }

    function update(address account) private {
        Info storage info = StakeMap[account];

        // new one
        if (info.account == address(0)) {
            info.claimBlock = block.number;
            info.account = account;
            StakeIndexes[account] = StakeArray.length;
            StakeArray.push(account);
            return;
        }

        if (block.number > info.claimBlock) {
            info.claimable = info.claimable + calcInterest(info.amounts, info.claimBlock);
            info.claimBlock = block.number;
        }
    }

    function _unstake(address account, uint256 amounts) private {
        Info storage info = StakeMap[account];
        require(info.account != address(0), "[Claim] need stake");
        require(info.amounts >= amounts, "[Withdraw] underflow");

        update(account);

        info.amounts -= amounts;
        _transfer(stakeToken, account, amounts);

        if (info.amounts > 0) {
            emit Unstake(account, amounts, info.amounts);
            return;
        }

        _claim(account);

        uint256 index = StakeIndexes[account];
        uint256 lastIndex = StakeArray.length - 1;

        if (index != lastIndex) {
            address temp = StakeArray[lastIndex];
            StakeArray[index] = temp;
            StakeIndexes[temp] = index;
        }

        delete StakeMap[account];
        delete StakeIndexes[account];
        StakeArray.pop();

        emit Unstake(account, amounts, info.amounts);
    }

    function _claim(address account) private {
        Info storage info = StakeMap[account];
        require(info.account != address(0), "[Claim] need stake");

        update(account);

        uint256 amounts = info.claimable;
        info.claimable = 0;
        info.claimed += amounts;
        _transferFrom(interestToken, owner(), account, amounts);

        emit Claim(account, amounts, info.claimed);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function transfer(
        address kip7,
        address to,
        uint256 amounts
    ) public onlyOwner {
        _transfer(kip7, to, amounts);
    }

    function stake(uint256 amounts) public whenNotPaused {
        require(amounts >= 1e13, "[Stake] more than 1e13");

        update(msg.sender);

        _transferFrom(stakeToken, msg.sender, address(this), amounts);

        Info storage info = StakeMap[msg.sender];
        info.amounts = info.amounts + amounts;
        info.lockedUntil = block.number + unstakeLock;

        emit Stake(msg.sender, amounts, info.amounts);
    }

    function claim() public {
        _claim(msg.sender);
    }

    function unstake(uint256 amounts) public {
        require(amounts >= 1e13, "[Stake] more than 1e13");
        Info storage info = StakeMap[msg.sender];
        require(info.account != address(0), "[Unstake] zero address");
        require(block.number > info.lockedUntil, "[Unstake] account locked");
        require(info.amounts >= amounts, "[Unstake] underflow");

        info.lockedUntil = block.number + unstakeLock;
        _unstake(msg.sender, amounts);
    }

    function calcInterest(uint256 amounts, uint256 before) private view returns (uint256) {
        if (before >= block.number || amounts == 0) {
            return 0;
        }

        //                       1000000000000000000
        //                                 131536000
        uint256 interest = (amounts / interestRate) / 31536000;
        return (block.number - before) * interest;
    }

    function getInfoByAccount(address account) public view returns (Info memory) {
        Info memory temp = StakeMap[account];
        if (temp.amounts == 0) {
            return temp;
        }
        temp.claimable = temp.claimable + calcInterest(temp.amounts, temp.claimBlock);
        return temp;
    }

    function getInfoByIndex(uint256 index) public view returns (Info memory) {
        require(StakeArray.length > 0, "[getInfoByIndex] empty");
        require(index < StakeArray.length, "[getInfoByIndex] overflow");
        address account = StakeArray[index];
        Info memory temp = StakeMap[account];
        if (temp.amounts == 0) {
            return temp;
        }
        temp.claimable = temp.claimable + calcInterest(temp.amounts, temp.claimBlock);
        return temp;
    }

    function length() public view returns (uint256) {
        return StakeArray.length;
    }

    function balance() public view returns (uint256) {
        (bool check, bytes memory data) = address(stakeToken).staticcall(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
        require(check == true, "[Balance] failed");
        uint256 amounts = abi.decode(data, (uint256));
        return amounts;
    }

    function cancel(uint256 index) public onlyOwner {
        require(StakeArray.length > 0, "[Cancel] empty");
        require(index < StakeArray.length, "[Cancel] overflow");

        Info memory info = getInfoByIndex(index);
        _unstake(info.account, info.amounts);
    }

    function cancel(address account) public onlyOwner {
        require(account != address(0), "[Cancel] zero address");

        Info memory info = StakeMap[account];
        require(info.account == account, "[Cancel] wrong address");
        _unstake(info.account, info.amounts);
    }
}
