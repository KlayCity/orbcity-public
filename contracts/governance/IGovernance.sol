// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ICandidateVoting.sol";
import "./ICouncil.sol";
import "./IDistrictHelper.sol";

contract IGovernance {
    struct CouncilMember {
        address user;
        string country;
        string text;
        uint256 voted;
    }
}
