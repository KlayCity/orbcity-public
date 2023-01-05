// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IGovernance.sol";

interface ICouncil {
    function addCouncilMembers(IGovernance.CouncilMember[] memory _councilMembers) external;

    function removeAllCouncilMember() external;
}
