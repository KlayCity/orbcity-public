// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract DistrictViewer is Ownable {
    address district;
    address staking;

    struct StakingInfo {
        address owner;
        uint256 tokenId;
        string country;
        uint256 stakedBlockNumber;
        uint256 playBlockNumber;
        uint256 accEarned;
    }

    constructor(address _district, address _staking) {
        district = _district;
        staking = _staking;
    }

    function set(address _district, address _staking) public onlyOwner {
        district = _district;
        staking = _staking;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        (bool check, bytes memory data) = address(district).staticcall(
            abi.encodeWithSignature("tokenURI(uint256)", tokenId)
        );
        require(check == true, "tokenURI false");
        string memory ret = abi.decode(data, (string));
        return ret;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner address to query the balance of
     * @return uint256 representing the amount owned by the passed address
     */
    function balanceOf(address owner) public view returns (uint256) {
        (bool check, bytes memory data) = staking.staticcall(
            abi.encodeWithSignature("getStakingTokenIds(address)", owner)
        );
        require(check == true, "[BalanceOf] getStakingTokenIds false");
        uint256 tokens = (abi.decode(data, (uint256[]))).length;

        (check, data) = address(district).staticcall(abi.encodeWithSignature("balanceOf(address)", owner));
        require(check == true, "[BalanceOf] balanceOf false");
        tokens = tokens + abi.decode(data, (uint256));

        return tokens;
    }

    /**
     * @dev Gets the owner of the specified token ID.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        (bool check, bytes memory data) = address(district).staticcall(
            abi.encodeWithSignature("ownerOf(uint256)", tokenId)
        );
        require(check == true, "[OwnerOf] district false");
        address ret = abi.decode(data, (address));

        if (ret != staking) {
            return ret;
        }
        (check, data) = address(staking).staticcall(abi.encodeWithSignature("getStakingInfo(uint256)", tokenId));
        require(check == true, "[OwnerOf] staking false");

        StakingInfo memory info = abi.decode(data, (StakingInfo));
        return info.owner;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        require(ownerOf(tokenId) == msg.sender, "[TransferFrom] not yours");
        (bool check, ) = address(district).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, tokenId)
        );
        require(check == true, "[TransferFrom] transferFrom false");
    }

    // function approve(address to, uint256 tokenId) public {
    //     // address owner = ownerOf(tokenId);
    //     // require(to != owner, "KIP17: approval to current owner");
    //     // require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "KIP17: approve caller is not owner nor approved for all");
    //     // _tokenApprovals[tokenId] = to;
    //     // emit Approval(owner, to, tokenId);
    // }
}
