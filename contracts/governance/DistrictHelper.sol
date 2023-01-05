// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../district/DistrictStaking.sol";
import "../district/DistrictInfo.sol";
import "../nft/District.sol";
import "./IDistrictHelper.sol";

contract DistrictHelper is IDistrictHelper {
    District private _district;
    DistrictStaking private _districtStaking;
    DistrictInfo private _districtInfo;

    constructor(
        District district_,
        DistrictStaking districtStaking_,
        DistrictInfo districtInfo_
    ) {
        _district = district_;
        _districtStaking = districtStaking_;
        _districtInfo = districtInfo_;
    }

    function isDistrictOwner(address owner) external view virtual override returns (bool) {
        uint256[] memory stakedTokens = _districtStaking.getStakingTokenIds(owner);

        if (stakedTokens.length > 0) {
            return true;
        }

        uint256[] memory tokens = _district.tokensOfOwner(owner);
        if (tokens.length > 0) {
            return true;
        }

        return false;
    }

    function isDistrictTokensOwner(address owner, uint256 tokenId) external view virtual override returns (bool) {
        uint256[] memory stakedTokens = _districtStaking.getStakingTokenIds(owner);

        for (uint256 i = 0; i < stakedTokens.length; i++) {
            if (tokenId == stakedTokens[i]) {
                return true;
            }
        }

        uint256[] memory tokens = _district.tokensOfOwner(owner);

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenId == tokens[i]) {
                return true;
            }
        }

        return false;
    }

    function haveCountry(address owner, string memory country) external view virtual override returns (bool) {
        uint256[] memory stakedTokens = _districtStaking.getStakingTokenIds(owner);

        for (uint256 i = 0; i < stakedTokens.length; i++) {
            string memory myCountry = _districtInfo.getAttribute(stakedTokens[i], "Country");

            if (stringCompare(country, myCountry)) {
                return true;
            }
        }

        uint256[] memory tokens = _district.tokensOfOwner(owner);

        for (uint256 i = 0; i < tokens.length; i++) {
            string memory myCountry = _districtInfo.getAttribute(tokens[i], "Country");

            if (stringCompare(country, myCountry)) {
                return true;
            }
        }

        return false;
    }

    function getOwnedTokenIds(address owner) external view virtual override returns (uint256[] memory) {
        uint256[] memory stakedTokens = _districtStaking.getStakingTokenIds(owner);

        uint256[] memory tokens = _district.tokensOfOwner(owner);

        uint256[] memory result = new uint256[](stakedTokens.length + tokens.length);

        for (uint256 i = 0; i < stakedTokens.length; i++) {
            result[i] = stakedTokens[i];
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            result[i + stakedTokens.length] = tokens[i];
        }

        return result;
    }

    function getTokenCount(address owner, string memory country) public view returns (uint256) {
        uint256[] memory stakedTokens = _districtStaking.getStakingTokenIds(owner);

        uint256[] memory tokens = _district.tokensOfOwner(owner);

        uint256 result;

        for (uint256 i = 0; i < stakedTokens.length; i++) {
            string memory _country = _districtInfo.getAttribute(stakedTokens[i], "Country");
            if (stringCompare(country, _country) == true) {
                result += 1;
            }
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            string memory _country = _districtInfo.getAttribute(tokens[i], "Country");
            if (stringCompare(country, _country) == true) {
                result += 1;
            }
        }

        return result;
    }

    function getTokenIds(address owner, string memory country) public view returns (uint256[] memory) {
        uint256[] memory stakedTokens = _districtStaking.getStakingTokenIds(owner);

        uint256[] memory tokens = _district.tokensOfOwner(owner);

        uint256 count = getTokenCount(owner, country);
        uint256[] memory result = new uint256[](count);
        uint256 index;
        for (uint256 i = 0; i < stakedTokens.length; i++) {
            string memory _country = _districtInfo.getAttribute(stakedTokens[i], "Country");

            if (stringCompare(country, _country) == true) {
                result[index] = stakedTokens[i];
                index++;
            }
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            string memory _country = _districtInfo.getAttribute(tokens[i], "Country");
            if (stringCompare(country, _country) == true) {
                result[index] = tokens[i];
                index++;
            }
        }

        return result;
    }

    function stringCompare(string memory org, string memory dst) internal pure returns (bool) {
        return keccak256(abi.encodePacked(org)) == keccak256(abi.encodePacked(dst));
    }

    function findIndex(string[] memory src, string memory dst) internal pure returns (uint256, bool) {
        for (uint256 i = 0; i < src.length; i++) {
            if (stringCompare(src[i], dst) == true) {
                return (i, true);
            }

            if (stringCompare(src[i], "") == true) {
                return (i, false);
            }
        }

        return (0, false);
    }

    function getLength(string[] memory src) internal pure returns (uint256) {
        uint256 cnt = 0;
        for (uint256 i = 0; i < src.length; i++) {
            if (stringCompare(src[i], "") == true) {
                break;
            }
            cnt++;
        }

        return cnt;
    }
}
