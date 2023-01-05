// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./TokenStake.sol";

contract OrbStake is TokenStake {
    constructor(address _stakeToken, address _rewardToken) TokenStake("Orb Stake", _stakeToken, _rewardToken) {}
}
