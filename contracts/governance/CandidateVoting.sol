// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../utils/Administered.sol";

import "./IDistrictHelper.sol";
import "./ICandidateVoting.sol";
import "./IGovernance.sol";

contract CandidateVoting is ICandidateVoting, Administered {
    uint256 private seq;

    IERC20 public govToken;
    IDistrictHelper public districtHelper;
    ICouncil public council;
    uint256 private registerCandidateStart;
    uint256 private registerCandidatePeriod;
    uint256 private registerCandidatePrice;
    address public communityTreasury;

    uint256 private voteCandidateStart;
    uint256 private voteCandidatePeriod;
    uint256 private cancelVotePrice;

    uint256 private councilMemberCount;

    struct Candidate {
        address user;
        string country;
        string text;
        uint256 vote;
        uint256 timestamp;
        uint256 keyIndex;
        uint256 countryIndex;
    }

    struct CandidateKey {
        address user;
        string country;
    }

    struct Vote {
        uint256 tokenId;
        address voter;
        address candidate;
        string country;
        uint256 timestamp;
        uint256 keyIndex;
    }

    CandidateKey[] public candidateKeys;
    mapping(address => string[]) public countriesByAddress;
    mapping(address => mapping(string => Candidate)) public candidateMap;
    IGovernance.CouncilMember[] private councilMembers;

    mapping(uint256 => Vote) public votes;
    uint256[] public voteKeys;

    event RegisterCandidate(address indexed user, string country, string text, uint256 price);

    event CancelCandidate(address indexed user, string country);

    event VoteCandidate(address indexed voter, uint256 tokenId, address candidate, string country);

    event CancelVoteCandidate(
        address indexed voter,
        uint256 indexed tokenId,
        address candidate,
        string country,
        uint256 price
    );

    event AddCouncilMembers(address[] candidates, string[] countries);
    event RemoveCouncilMembers(address[] candidates, string[] countries);

    constructor() {}

    function setContracts(
        IERC20 govToken_,
        IDistrictHelper districtHelper_,
        ICouncil council_
    ) public onlyAdmin {
        govToken = govToken_;
        districtHelper = districtHelper_;
        council = council_;
    }

    function setVariables(
        uint256 seq_,
        uint256 registerCandidateStart_,
        uint256 registerCandidatePeriod_,
        uint256 registerCandidatePrice_,
        address communityTreasury_,
        uint256 voteCandidateStart_,
        uint256 voteCandidatePeriod_,
        uint256 cancelVotePrice_,
        uint256 councilMemberCount_
    ) public onlyAdmin {
        seq = seq_;
        registerCandidateStart = registerCandidateStart_;
        registerCandidatePeriod = registerCandidatePeriod_;
        registerCandidatePrice = registerCandidatePrice_;
        communityTreasury = communityTreasury_;

        voteCandidateStart = voteCandidateStart_;
        voteCandidatePeriod = voteCandidatePeriod_;
        cancelVotePrice = cancelVotePrice_;

        councilMemberCount = councilMemberCount_;
    }

    function addCouncilMembers(address[] memory candidates, string[] memory countries) public override onlyAdmin {
        require(candidates.length == countries.length, "diff length");
        require(candidates.length == councilMemberCount, "not enough count");
        require(block.timestamp >= voteCandidateStart + voteCandidatePeriod, "not finish vote");
        for (uint256 i = 0; i < candidates.length; i++) {
            addCouncilMember(candidates[i], countries[i]);
        }

        IGovernance.CouncilMember[] memory _councilMembers = new IGovernance.CouncilMember[](councilMembers.length);

        for (uint256 i = 0; i < councilMembers.length; i++) {
            _councilMembers[i].user = councilMembers[i].user;
            _councilMembers[i].country = councilMembers[i].country;
            _councilMembers[i].text = councilMembers[i].text;
            _councilMembers[i].voted = councilMembers[i].voted;
        }

        council.addCouncilMembers(_councilMembers);

        emit AddCouncilMembers(candidates, countries);
    }

    function removeAllCouncilMember() public onlyAdmin {
        uint256 count = councilMembers.length;

        address[] memory candidates = new address[](count);
        string[] memory countries = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            candidates[i] = councilMembers[i].user;
            countries[i] = councilMembers[i].country;
        }

        delete councilMembers;

        emit RemoveCouncilMembers(candidates, countries);
    }

    function registerCandidate(string memory country, string memory text) public {
        // check register peiod
        require(
            block.timestamp >= registerCandidateStart &&
                block.timestamp <= registerCandidateStart + registerCandidatePeriod,
            "not register period"
        );

        // prevent duplicate
        require(candidateMap[msg.sender][country].user == address(0), "duplicate");

        // prevent not district owner
        require(districtHelper.isDistrictOwner(msg.sender) == true, "not district owner");

        // check have country
        require(districtHelper.haveCountry(msg.sender, country), "no country");

        // transfer treasury community
        govToken.transferFrom(msg.sender, communityTreasury, registerCandidatePrice);

        // add candidate
        Candidate memory candidate = Candidate({
            user: msg.sender,
            country: country,
            text: text,
            vote: 0,
            timestamp: block.timestamp,
            keyIndex: 0,
            countryIndex: 0
        });

        addCandidate(candidate);

        emit RegisterCandidate(msg.sender, country, text, registerCandidatePrice);
    }

    function cancelCandidate(string memory country) public {
        // check register peiod
        require(
            block.timestamp >= registerCandidateStart &&
                block.timestamp <= registerCandidateStart + registerCandidatePeriod,
            "not register period"
        );

        removeCandidate(msg.sender, country);

        emit CancelCandidate(msg.sender, country);
    }

    function voteCandidate(
        uint256[] memory tokenIds,
        address candidate,
        string memory country
    ) public {
        // check period
        require(
            block.timestamp >= voteCandidateStart && block.timestamp <= voteCandidateStart + voteCandidatePeriod,
            "not vote period"
        );

        Candidate storage candidateObj = candidateMap[candidate][country];
        // check exist candidate
        require(candidateObj.user != address(0), "no candidate");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // check district owner
            require(districtHelper.isDistrictTokensOwner(msg.sender, tokenIds[i]) == true, "tokenId not yours");

            // prevent duplicate vote same tokenId
            require(votes[tokenIds[i]].voter == address(0), "duplicate");

            voteKeys.push(tokenIds[i]);

            votes[tokenIds[i]] = Vote({
                tokenId: tokenIds[i],
                voter: msg.sender,
                candidate: candidate,
                country: country,
                timestamp: block.timestamp,
                keyIndex: voteKeys.length - 1
            });

            emit VoteCandidate(msg.sender, tokenIds[i], candidate, country);
        }

        candidateObj.vote += tokenIds.length;
    }

    function cancelVoteCandidate(uint256 tokenId) public {
        // check period
        require(
            block.timestamp >= voteCandidateStart && block.timestamp <= voteCandidateStart + voteCandidatePeriod,
            "not vote period"
        );

        Vote storage vote = votes[tokenId];
        require(vote.voter != address(0), "no vote");

        // need 100 orb
        govToken.transferFrom(msg.sender, communityTreasury, cancelVotePrice);

        uint256 index = vote.keyIndex;
        uint256 lastIndex = voteKeys.length - 1;

        Candidate storage candidateObj = candidateMap[vote.candidate][vote.country];
        candidateObj.vote -= 1;

        if (index != lastIndex) {
            uint256 lastKey = voteKeys[lastIndex];
            votes[lastKey].keyIndex = index;
            voteKeys[index] = lastKey;
        }

        emit CancelVoteCandidate(msg.sender, tokenId, vote.candidate, vote.country, cancelVotePrice);

        voteKeys.pop();
        delete votes[tokenId];
    }

    /***************************************************************
        public view functions
    ***************************************************************/

    function getRegisterCandidateList(address user)
        public
        view
        returns (
            address[] memory _users,
            string[] memory _countries,
            string[] memory _texts,
            uint256[] memory _votes
        )
    {
        uint256 length = countriesByAddress[user].length;
        _users = new address[](length);
        _countries = new string[](length);
        _texts = new string[](length);
        _votes = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            Candidate storage candidate = candidateMap[user][countriesByAddress[user][i]];
            _users[i] = candidate.user;
            _countries[i] = candidate.country;
            _texts[i] = candidate.text;
            _votes[i] = candidate.vote;
        }
    }

    function getInfo()
        public
        view
        returns (
            uint256 _seq,
            uint256 _registerCandidateStart,
            uint256 _registerCandidatePeriod,
            uint256 _registerCandidatePrice,
            uint256 _voteCandidateStart,
            uint256 _voteCandidatePeriod,
            uint256 _cancelVotePrice,
            uint256 _votedTotal,
            uint256 _councilMemberCount
        )
    {
        _seq = seq;
        _registerCandidateStart = registerCandidateStart;
        _registerCandidatePeriod = registerCandidatePeriod;
        _registerCandidatePrice = registerCandidatePrice;
        _voteCandidateStart = voteCandidateStart;
        _voteCandidatePeriod = voteCandidatePeriod;
        _cancelVotePrice = cancelVotePrice;
        _votedTotal = voteKeys.length;
        _councilMemberCount = councilMemberCount;
    }

    function getCouncilMembers() public view returns (IGovernance.CouncilMember[] memory) {
        return councilMembers;
    }

    function getCandidateKeyLength() public view returns (uint256) {
        return candidateKeys.length;
    }

    function getCandidateList(uint256 offset, uint256 count) public view returns (Candidate[] memory) {
        uint256 workCnt = count;
        if (candidateKeys.length < workCnt) {
            workCnt = candidateKeys.length;
        }

        Candidate[] memory result = new Candidate[](workCnt);
        for (uint256 i = 0; i < workCnt; i++) {
            CandidateKey storage key = candidateKeys[i + offset];
            result[i] = candidateMap[key.user][key.country];
        }

        return result;
    }

    function getCandidateVote(address user) public view returns (Vote[] memory _votes, uint256 _totalCount) {
        uint256[] memory tokenIds = districtHelper.getOwnedTokenIds(user);

        uint256 voteCount;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (votes[tokenIds[i]].voter != address(0)) {
                voteCount += 1;
            }
        }

        _votes = new Vote[](voteCount);

        uint256 index;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (votes[tokenIds[i]].voter != address(0)) {
                _votes[index] = votes[tokenIds[i]];
                index += 1;
            }
        }

        _totalCount = tokenIds.length;
    }

    /***************************************************************
        private or internal functions
    ***************************************************************/

    function addCandidate(Candidate memory candidate) private {
        require(candidateMap[candidate.user][candidate.country].user == address(0), "duplicate");
        candidateMap[candidate.user][candidate.country] = candidate;

        CandidateKey memory key = CandidateKey({user: candidate.user, country: candidate.country});

        candidateKeys.push(key);
        countriesByAddress[candidate.user].push(candidate.country);

        Candidate storage newCandidate = candidateMap[candidate.user][candidate.country];
        newCandidate.keyIndex = candidateKeys.length - 1;
        newCandidate.countryIndex = countriesByAddress[candidate.user].length - 1;
    }

    function removeCandidate(address user, string memory country) private {
        require(candidateMap[user][country].user != address(0), "no data");

        uint256 index = candidateMap[user][country].keyIndex;
        uint256 lastIndex = candidateKeys.length - 1;

        if (index != lastIndex) {
            CandidateKey storage lastKey = candidateKeys[lastIndex];
            candidateMap[lastKey.user][lastKey.country].keyIndex = index;
            candidateKeys[index] = lastKey;
        }

        uint256 countryIndex = candidateMap[user][country].countryIndex;
        uint256 lastCountryIndex = countriesByAddress[user].length - 1;

        if (countryIndex != lastCountryIndex) {
            string storage lastCountry = countriesByAddress[user][lastCountryIndex];

            candidateMap[user][lastCountry].countryIndex = countryIndex;

            countriesByAddress[user][countryIndex] = lastCountry;
        }

        candidateKeys.pop();
        countriesByAddress[user].pop();
        delete candidateMap[user][country];
    }

    function stringCompare(string memory org, string memory dst) internal pure returns (bool) {
        return keccak256(abi.encodePacked(org)) == keccak256(abi.encodePacked(dst));
    }

    function addCouncilMember(address candidate, string memory country) private {
        Candidate storage candidateObj = candidateMap[candidate][country];

        councilMembers.push(
            IGovernance.CouncilMember({
                user: candidate,
                country: country,
                text: candidateObj.text,
                voted: candidateObj.vote
            })
        );
    }
}
