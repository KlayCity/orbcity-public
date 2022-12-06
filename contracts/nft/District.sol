// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../utils/Withdrawable.sol";
import "../utils/ERC721Freezable.sol";

contract District is
    Ownable,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Pausable,
    ERC721URIStorage,
    ERC721Royalty,
    Withdrawable,
    ERC721Freezable
{
    using Counters for Counters.Counter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    Counters.Counter private _tokenIdTracker;
    string public _baseTokenURI;
    bool public useTransferRole = false;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(WITHDRAWER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(TRANSFER_ROLE, _msgSender());
        _baseTokenURI = baseTokenURI;
        mint(_msgSender());
        freezeToken(0, true);
    }

    function setActivateTransferRole(bool flag) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "setActivateTransferRole: must have admin role");
        useTransferRole = flag;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseTokenURI) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "setBaseURI: must have minter role");
        _baseTokenURI = baseTokenURI;
    }

    function setTokenURI(uint256 tokenId, string memory uri) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "setTokenURI: must have minter role");
        _setTokenURI(tokenId, uri);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function mint(address to) public returns (uint256 tokenId) {
        require(hasRole(MINTER_ROLE, _msgSender()), "mint: must have minter role to mint");

        tokenId = _tokenIdTracker.current();
        _mint(to, tokenId);
        _tokenIdTracker.increment();
    }

    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "pause: must have pauser role to pause");
        _pause();
    }

    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "unpause: must have pauser role to unpause");
        _unpause();
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage, ERC721Royalty) {
        super._burn(tokenId);
    }

    function freezeAccount(address account, bool flag) public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "freeze: must have pauser role to freeze");
        _freezeAccount(account, flag);
    }

    function freezeToken(uint256 tokenId, bool flag) public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "freeze: must have pauser role to freeze");
        _freezeToken(tokenId, flag);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Pausable, ERC721Enumerable, ERC721Freezable) {
        require(
            paused() == false || hasRole(PAUSER_ROLE, _msgSender()) == true,
            "ERC721Pausable: token transfer while paused"
        );

        require(
            useTransferRole == false || ownerOf(tokenId) == _msgSender() || hasRole(TRANSFER_ROLE, _msgSender()),
            "transfer: owner or need transfer role"
        );

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControlEnumerable, ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function approve(address to, uint256 tokenId) public virtual override(ERC721, ERC721Freezable) {
        super.approve(to, tokenId);
    }
}
