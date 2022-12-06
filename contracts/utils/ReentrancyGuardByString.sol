// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

contract ReentrancyGuardByString {
    mapping(string => bool) public entered;

    modifier nonReentrantString(string memory str) {
        require(!entered[str], "ReentrancyGuardByString: prevent execute function asynchronous");

        entered[str] = true;

        _;

        entered[str] = false;
    }
}
