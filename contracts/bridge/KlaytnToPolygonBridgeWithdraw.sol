// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../utils/Withdrawable.sol";
import "../utils/ERC721Freezable.sol";
import "./KlaytnToPolygonBridgeConfirm.sol";

contract KlaytnToPolygonBridgeWithdraw is Ownable, AccessControlEnumerable, Pausable, Withdrawable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CONFIRM_ROLE = keccak256("CONFIRM_ROLE");

    enum Type {
        Orb,
        Lay,
        District,
        BuildingMintpass
    }

    event Withdraw(
        string txId,
        string name,
        uint256[] tokenIds,
        uint256 amounts,
        address indexed to,
        uint256 blockNumber
    );

    event Confirm(string txId, Type name, uint256[] tokenIds, uint256 amounts, address indexed to, uint256 blockNumber);
    event Deny(string txId, Type name, uint256[] tokenIds, uint256 amounts, address indexed to, uint256 blockNumber);

    struct TX {
        string id;
        int8 state;
        Type name;
        uint256[] tokenIds;
        uint256 amounts;
        address to;
        uint256 confirmation;
    }

    IERC721 public district;
    IERC721 public mintpass;
    IERC20 public orb;
    IERC20 public lay;

    mapping(string => TX) public txMap;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(WITHDRAWER_ROLE, _msgSender());
    }

    function pause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "pause: must have pauser role to pause");
        _pause();
    }

    function unpause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "unpause: must have pauser role to unpause");
        _unpause();
    }

    function mintDistrict(
        string calldata txId,
        uint256[] calldata tokenIds,
        address to
    ) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "mint: must have minter role to mint");

        TX storage _tx = txMap[txId];

        require(_tx.state == 0, "already withdrawal");

        _tx.id = txId;
        _tx.name = Type.District;
        _tx.tokenIds = tokenIds;
        _tx.to = to;
        _tx.state = 1;
        _tx.confirmation = block.number;

        //   klaytnToPolygonBridgeConfirm.mintDistrict(txId, tokenIds, to);

        emit Withdraw(_tx.id, "District", _tx.tokenIds, _tx.amounts, _tx.to, _tx.confirmation);
    }

    function mintBuildginMintpass(
        string calldata txId,
        uint256[] calldata tokenIds,
        address to
    ) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "mint: must have minter role to mint");

        TX storage _tx = txMap[txId];

        require(_tx.state == 0, "already withdrawal");

        _tx.id = txId;
        _tx.name = Type.BuildingMintpass;
        _tx.tokenIds = tokenIds;
        _tx.to = to;
        _tx.state = 1;
        _tx.confirmation = block.number;

        //  klaytnToPolygonBridgeConfirm.mintBuildingMintpass(txId, tokenIds, to);

        emit Withdraw(_tx.id, "BuildingMintpass", _tx.tokenIds, _tx.amounts, _tx.to, _tx.confirmation);
    }

    function mintLay(
        string calldata txId,
        uint256 amounts,
        address to
    ) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "mint: must have minter role to mint");

        TX storage _tx = txMap[txId];

        require(_tx.state == 0, "already withdrawal");

        _tx.id = txId;
        _tx.name = Type.Lay;
        _tx.amounts = amounts;
        _tx.to = to;
        _tx.state = 1;
        _tx.confirmation = block.number;

        //   klaytnToPolygonBridgeConfirm.mintLay(txId, amounts, to);

        emit Withdraw(_tx.id, "Lay", _tx.tokenIds, _tx.amounts, _tx.to, _tx.confirmation);
    }

    function mintOrb(
        string calldata txId,
        uint256 amounts,
        address to
    ) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "mint: must have minter role to mint");

        TX storage _tx = txMap[txId];

        require(_tx.state == 0, "already withdrawal");

        _tx.id = txId;
        _tx.name = Type.Orb;
        _tx.amounts = amounts;
        _tx.to = to;
        _tx.state = 1;
        _tx.confirmation = block.number;

        //   klaytnToPolygonBridgeConfirm.mintOrb(txId, amounts, to);

        emit Withdraw(_tx.id, "Orb", _tx.tokenIds, _tx.amounts, _tx.to, _tx.confirmation);
    }

    function confirm(string calldata txId) public whenNotPaused {
        require(hasRole(CONFIRM_ROLE, _msgSender()), "confirm: must have confirm role to mint");

        TX storage _tx = txMap[txId];

        if (_tx.state == 2) {
            return;
        }

        require(_tx.state != 1, "not ready");
        require(_tx.confirmation > block.number + 30, "not ready");

        _tx.state = 2;
        _tx.confirmation = block.number;

        if (_tx.name == Type.District) {
            for (uint256 i = 0; i < _tx.tokenIds.length; ++i) {
                district.transferFrom(address(this), _tx.to, _tx.tokenIds[i]);
            }
        } else if (_tx.name == Type.BuildingMintpass) {
            for (uint256 i = 0; i < _tx.tokenIds.length; ++i) {
                mintpass.transferFrom(address(this), _tx.to, _tx.tokenIds[i]);
            }
        } else if (_tx.name == Type.Orb) {
            orb.transfer(_tx.to, _tx.amounts);
        } else if (_tx.name == Type.Lay) {
            lay.transfer(_tx.to, _tx.amounts);
        }

        emit Confirm(_tx.id, _tx.name, _tx.tokenIds, _tx.amounts, _tx.to, _tx.confirmation);
    }

    function deny(string calldata txId) public whenNotPaused {
        require(hasRole(CONFIRM_ROLE, _msgSender()), "deny: must have confirm role to mint");

        TX storage _tx = txMap[txId];
        require(_tx.state != 1, "not ready");
        require(_tx.confirmation > block.number + 30, "not ready");

        _tx.state = 3;
        _tx.confirmation = block.number;
        emit Deny(_tx.id, _tx.name, _tx.tokenIds, _tx.amounts, _tx.to, _tx.confirmation);
    }

    function getTx(string calldata txId) public view returns (TX memory) {
        return txMap[txId];
    }
}
