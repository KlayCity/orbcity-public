// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../utils/Administered.sol";

import "./ICandidateVoting.sol";
import "./ICouncil.sol";
import "./IDistrictHelper.sol";

contract Governance is Administered {
    uint256 public lastSeq;

    ICandidateVoting[] public candidateVotings;
    ICouncil[] public councils;
    ICandidateVoting[] public removedCandidateVotings;
    ICouncil[] public removedCouncils;
    IERC20 public govToken;
    mapping(address => uint256) private candidateVotingBN;
    mapping(address => uint256) private councilBN;

    event AddSeason(uint256 indexed seq, address candidateVoting, address council);
    event RemoveSeason(uint256 indexed seq, address candidateVoting, address council);

    event ChangeCandidateVoting(uint256 seq, address oldCandidateVoting, address newCandidateVoting);

    event ChangeCouncil(uint256 seq, address oldCouncil, address newCouncil);

    constructor(IERC20 govToken_) {
        govToken = govToken_;
        lastSeq = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    }

    function setContracts(IERC20 govToken_) public onlyAdmin {
        govToken = govToken_;
    }

    function emergencyWithdraw(uint256 amount) public onlyAdmin {
        govToken.transfer(msg.sender, amount);
    }

    function addSeason(ICandidateVoting candidateVoting, ICouncil council) public onlyAdmin {
        govToken.approve(address(council), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        candidateVotings.push(candidateVoting);
        councils.push(council);

        candidateVotingBN[address(candidateVoting)] = block.number;
        councilBN[address(council)] = block.number;

        if (lastSeq == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) {
            lastSeq = 0;
        } else {
            lastSeq++;
        }

        emit AddSeason(lastSeq, address(candidateVoting), address(council));
    }

    function changeSeason(
        uint256 index,
        ICandidateVoting candidateVoting,
        ICouncil council
    ) public onlyAdmin {
        ICandidateVoting oldCandidateVoting = candidateVotings[index];

        if (address(candidateVoting) != address(oldCandidateVoting)) {
            removedCandidateVotings.push(oldCandidateVoting);
            candidateVotings[index] = candidateVoting;
            candidateVotingBN[address(candidateVoting)] = block.number;
            emit ChangeCandidateVoting(index, address(oldCandidateVoting), address(candidateVoting));
        }

        ICouncil oldCouncil = councils[index];
        if (address(council) != address(oldCouncil)) {
            removedCouncils.push(oldCouncil);
            councils[index] = council;
            councilBN[address(council)] = block.number;

            emit ChangeCouncil(index, address(oldCouncil), address(council));
        }
    }

    function removeLastSeason() public onlyAdmin {
        uint256 lastIndex = candidateVotings.length - 1;

        emit RemoveSeason(lastSeq, address(candidateVotings[lastIndex]), address(councils[lastIndex]));

        removedCandidateVotings.push(candidateVotings[lastIndex]);
        removedCouncils.push(councils[lastIndex]);
        candidateVotings.pop();
        councils.pop();

        if (lastSeq == 0) {
            lastSeq = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        } else {
            lastSeq--;
        }
    }

    function getRecentlyInfo(uint256 count)
        public
        view
        returns (
            uint256 _lastSeq,
            address[] memory _candidateVotings,
            address[] memory _councils
        )
    {
        uint256 realCount = candidateVotings.length;
        if (count < realCount) {
            realCount = count;
        }

        _candidateVotings = new address[](realCount);
        _councils = new address[](realCount);

        for (uint256 i = 0; i < realCount; i++) {
            _candidateVotings[i] = address(candidateVotings[candidateVotings.length - 1 - i]);

            _councils[i] = address(councils[councils.length - 1 - i]);
        }

        _lastSeq = lastSeq;
    }

    function getContractInfo(uint256 seq) public view returns (address, address) {
        return (address(candidateVotings[seq]), address(councils[seq]));
    }

    function getContractBN(uint256 seq) public view returns (uint256, uint256) {
        return (candidateVotingBN[address(candidateVotings[seq])], councilBN[address(councils[seq])]);
    }
}
