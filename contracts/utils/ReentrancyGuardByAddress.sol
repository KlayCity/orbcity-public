// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

contract ReentrancyGuardByAddress {
    mapping(address => bool) public entered;

    modifier nonReentrantAddress(address addr) {
        require(!entered[addr], "ReentrancyGuardByAddress: prevent execute function asynchronous");

        entered[addr] = true;

        _;

        entered[addr] = false;
    }
}
