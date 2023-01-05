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
import "../utils/IChildToken.sol";
import "../utils/NativeMetaTransaction.sol";
import "../utils/IMintableERC721.sol";

contract DistrictRoot is
    Ownable,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Pausable,
    ERC721URIStorage,
    ERC721Royalty,
    Withdrawable,
    ERC721Freezable,
    NativeMetaTransaction,
    IMintableERC721
{
    using Counters for Counters.Counter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");
    bytes32 public constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");

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
        _setupRole(PREDICATE_ROLE, address(0x932532aA4c0174b8453839A6E44eE09Cc615F2b7));
        _baseTokenURI = baseTokenURI;
        _initializeEIP712(name);
    }

    function msgSender() internal view returns (address payable sender) {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }

    function _msgSender() internal view override returns (address) {
        return msgSender();
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
        override(ERC721, AccessControlEnumerable, ERC721Enumerable, ERC721Royalty, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function approve(address to, uint256 tokenId) public virtual override(ERC721, ERC721Freezable, IERC721) {
        super.approve(to, tokenId);
    }

    function tokensOfOwner(address owner) public view returns (uint256[] memory result) {
        uint256 count = balanceOf(owner);
        result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tokenOfOwnerByIndex(owner, i);
        }

        return result;
    }

    /**
     * @dev See {IMintableERC721-mint}.
     */
    function mint(address user, uint256 tokenId) external override {
        require(hasRole(PREDICATE_ROLE, _msgSender()), "mint: must have minter role to mint");
        _mint(user, tokenId);
    }

    /**
     * If you're attempting to bring metadata associated with token
     * from L2 to L1, you must implement this method, to be invoked
     * when minting token back on L1, during exit
     */
    function setTokenMetadata(uint256 tokenId, bytes memory data) internal virtual {
        // This function should decode metadata obtained from L2
        // and attempt to set it for this `tokenId`
        //
        // Following is just a default implementation, feel
        // free to define your own encoding/ decoding scheme
        // for L2 -> L1 token metadata transfer
        string memory uri = abi.decode(data, (string));

        _setTokenURI(tokenId, uri);
    }

    /**
     * @dev See {IMintableERC721-mint}.
     *
     * If you're attempting to bring metadata associated with token
     * from L2 to L1, you must implement this method
     */
    function mint(
        address user,
        uint256 tokenId,
        bytes calldata metaData
    ) external override {
        require(hasRole(PREDICATE_ROLE, _msgSender()), "mint: must have minter role to mint");
        _mint(user, tokenId);
        setTokenMetadata(tokenId, metaData);
    }

    /**
     * @dev See {IMintableERC721-exists}.
     */

    function exists(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }
}
