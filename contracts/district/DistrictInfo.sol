// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../utils/Administered.sol";
import "../utils/StringHelper.sol";
import "./DistrictInfo.sol";

contract DistrictInfo is Administered {
    using StringHelper for string;
    using StringHelper for uint256;

    // tokenId => key => value
    mapping(uint256 => mapping(string => string)) public attributes;

    // country name => tokenId array
    mapping(string => uint256[]) public countryTokenIds;

    // tokenId => countryTokenIds index
    mapping(uint256 => uint256) private countryTokenIdIndexes;

    event SetAttribute(uint256 indexed tokenId, string key, string value);

    constructor() {}

    function getAttribute(uint256 tokenId, string memory key) public view returns (string memory) {
        require(existAttribute(tokenId, key), "does not exist the key in districtInfo");
        return attributes[tokenId][key];
    }

    function getAttribute(uint256[] memory tokenIds, string memory key) public view returns (string[] memory) {
        string[] memory result = new string[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            result[i] = getAttribute(tokenIds[i], key);
        }

        return result;
    }

    function setAttribute(
        uint256 tokenId,
        string memory key,
        string memory value
    ) public onlyAdmin {
        if (key.compare("Country") == true) {
            if (existAttribute(tokenId, key) == true) {
                string memory oldCountry = getAttribute(tokenId, key);
                deleteCountryTokenId(tokenId, oldCountry);
            }

            countryTokenIds[value].push(tokenId);
            countryTokenIdIndexes[tokenId] = countryTokenIds[value].length - 1;
        }

        attributes[tokenId][key] = value;

        emit SetAttribute(tokenId, key, value);
    }

    function setAttribute(
        uint256 tokenId,
        string[] memory keys,
        string[] memory values
    ) public onlyAdmin {
        require(keys.length == values.length, "keys and values count different");

        for (uint256 i = 0; i < keys.length; i++) {
            setAttribute(tokenId, keys[i], values[i]);
        }
    }

    function setBulkAttributes(
        uint256[] memory tokenIds,
        string[] memory keys,
        string[] memory values
    ) public onlyAdmin {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            for (uint256 j = 0; j < keys.length; j++) {
                setAttribute(tokenIds[i], keys[j], values[i * keys.length + j]);
            }
        }
    }

    function getTokenIdsByCountry(string memory country) public view returns (uint256[] memory) {
        return countryTokenIds[country];
    }

    function existAttribute(uint256 tokenId, string memory key) public view returns (bool) {
        return (keccak256(abi.encodePacked((attributes[tokenId][key]))) != keccak256(abi.encodePacked((""))));
    }

    function deleteCountryTokenId(uint256 tokenId, string memory country) private {
        uint256[] storage tokenIds = countryTokenIds[country];

        uint256 index = countryTokenIdIndexes[tokenId];
        uint256 lastIndex = tokenIds.length - 1;

        if (index != lastIndex) {
            uint256 temp = tokenIds[lastIndex];
            countryTokenIdIndexes[temp] = index;
            tokenIds[index] = temp;
        }

        tokenIds.pop();
        delete countryTokenIdIndexes[tokenId];
    }
}
