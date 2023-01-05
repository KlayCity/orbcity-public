// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IDistrictHelper {
    function isDistrictOwner(address owner) external view returns (bool);

    function isDistrictTokensOwner(address owner, uint256 tokenId) external view returns (bool);

    function haveCountry(address owner, string memory country) external view returns (bool);

    function getOwnedTokenIds(address owner) external view returns (uint256[] memory);
}
