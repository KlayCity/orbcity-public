// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

interface ICandidateVoting {
    function addCouncilMembers(address[] memory candidates, string[] memory countries) external;
}
