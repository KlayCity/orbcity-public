// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../utils/Withdrawable.sol";
import "../utils/ERC721Freezable.sol";
import "../nft/District.sol";

contract DistrictWithdrawer is Ownable, AccessControlEnumerable, Pausable, Withdrawable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    event Insert(string txId, uint256 tokenId, address to, uint256 blockNumber);

    District public district;

    struct TX {
        string id;
        int8 state;
        uint256 tokenId;
        address to;
        uint256 confirmation;
    }

    mapping(string => TX) public txMap;

    constructor(District _district) {
        district = _district;
    }

    function pause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "pause: must have pauser role to pause");
        _pause();
    }

    function unpause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "unpause: must have pauser role to unpause");
        _unpause();
    }

    function insert(
        string memory txId,
        uint256 tokenId,
        address to
    ) public whenNotPaused {
        require(hasRole(MINTER_ROLE, _msgSender()), "insert: must have minter role to mint");
        require(txMap[txId].tokenId == 0, "already inserted");
        require(tokenId > 0, "zero token id");
        require(district.ownerOf(tokenId) == address(this), "empty district");

        TX memory _tx;
        _tx.id = txId;
        _tx.tokenId = tokenId;
        _tx.to = to;
        txMap[txId] = _tx;

        emit Insert(txId, tokenId, to, block.number);
    }

    function update(string memory id) public whenNotPaused {
        require(hasRole(MINTER_ROLE, _msgSender()), "withdraw: must have minter role to mint");

        TX storage _tx = txMap[id];
        require(_tx.tokenId > 0, "");
        require(_tx.state == 0, "");
        require(_tx.confirmation == 0, "");

        _tx.state = 1;
        _tx.confirmation = block.number;

        district.transferFrom(address(this), _tx.to, _tx.tokenId);
    }
}
