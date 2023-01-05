// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../utils/Administered.sol";

import "./ICouncil.sol";

contract Council is ICouncil, Administered {
    uint256 public seq;
    ERC20Burnable public govToken;
    uint256 public proposePrice;
    uint256 public councilReviewPeriod;
    uint256 public userVotePeriod;
    uint256 public needCouncilMemberAgreeCnt;
    uint256 public lockupTokenBlock;
    uint256 public rewardRate;
    address public rewardBank;
    uint256 public councilFinish;

    uint256 private oneYear;

    enum ProposalState {
        CouncilReview,
        UserVote,
        TeamReview,
        Drop,
        Complete
    }

    struct Proposal {
        address proposer;
        uint256 proposalId;
        string title;
        string content;
    }

    struct ProposalData {
        ProposalState state;
        bool isUserVoteWin;
        uint256 startTime;
        uint256 councilReviewFinish;
        uint256 userVoteFinish;
        uint256 lockupTokenBlock;
        string teamReview;
        uint256 councilYes;
        uint256 councilNo;
        IGovernance.CouncilMember[] councilYesUsers;
        IGovernance.CouncilMember[] councilNoUsers;
        uint256 userYes;
        uint256 userNo;
    }

    struct UserVoteInfo {
        address user;
        bool yesOrNo;
        uint256 tokenCnt;
    }

    struct ProposalVote {
        uint256 rewardRate;
        mapping(address => uint256) yesTokens;
        mapping(address => uint256) yesTokenRewards;
        mapping(address => uint256) yesTokenStartBlocks;
        mapping(address => uint256) noTokens;
        mapping(address => uint256) noTokenRewards;
        mapping(address => uint256) noTokenStartBlocks;
        mapping(address => uint256) claimedTokens;
        mapping(address => uint256) claimedTokenRewards;
        mapping(address => uint256) lockFinishBlocks;
        mapping(address => bool) councilVotes;
        mapping(address => bool) councilYesOrNoVotes;
        IGovernance.CouncilMember[] voteCouncilMembers;
        UserVoteInfo[] userVoteInfos;
    }

    IGovernance.CouncilMember[] private councilMembers;
    uint256 public proposalCnt;
    Proposal[] private proposals;
    ProposalData[] private proposalDatas;
    ProposalVote[] public proposalVotes;

    event Propose(address indexed proposer, uint256 indexed proposalId, string title, string content);

    event CouncilVote(
        uint256 indexed proposalId,
        address indexed councilMember,
        string country,
        string text,
        bool yesOrNo
    );

    event FinishCouncilVote(uint256 indexed proposalId, ProposalState state);
    event UserVote(uint256 indexed proposalId, address indexed voter, bool yesOrNo, uint256 tokenCount);

    event FinishUserVote(uint256 indexed proposalId, ProposalState state, bool win);

    event WriteTeamReview(uint256 indexed proposalId, string review);

    event ClaimVotedToken(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 tokenCount,
        uint256 rewardTokenCount
    );

    constructor() {
        oneYear = 1 days * 365;
    }

    function setContracts(ERC20Burnable govToken_, address rewardBank_) public onlyAdmin {
        govToken = govToken_;
        rewardBank = rewardBank_;
    }

    function setVariables(
        uint256 seq_,
        uint256 proposePrice_,
        uint256 councilReviewPeriod_,
        uint256 userVotePeriod_,
        uint256 needCouncilMemberAgreeCnt_,
        uint256 lockupTokenBlock_,
        uint256 rewardRate_,
        uint256 councilFinish_
    ) public onlyAdmin {
        seq = seq_;
        proposePrice = proposePrice_;
        councilReviewPeriod = councilReviewPeriod_;
        userVotePeriod = userVotePeriod_;
        needCouncilMemberAgreeCnt = needCouncilMemberAgreeCnt_;
        lockupTokenBlock = lockupTokenBlock_;
        rewardRate = rewardRate_;
        councilFinish = councilFinish_;
    }

    function addCouncilMembers(IGovernance.CouncilMember[] memory _councilMembers) public override onlyAdmin {
        for (uint256 i = 0; i < _councilMembers.length; i++) {
            councilMembers.push(_councilMembers[i]);
        }
    }

    function removeAllCouncilMember() public override onlyAdmin {
        delete councilMembers;
    }

    function propose(string memory title, string memory content) public {
        require(block.timestamp < councilFinish, "finish council");

        require(councilMembers.length > 0, "no council member");

        govToken.burnFrom(msg.sender, proposePrice);

        uint256 proposalId = proposalCnt;
        proposalCnt++;

        proposals.push(Proposal({proposer: msg.sender, proposalId: proposalId, title: title, content: content}));

        ProposalData storage proposalData = proposalDatas.push();

        proposalData.startTime = block.timestamp;
        proposalData.councilReviewFinish = block.timestamp + councilReviewPeriod;
        proposalData.userVoteFinish = block.timestamp + councilReviewPeriod + userVotePeriod;
        proposalData.lockupTokenBlock = lockupTokenBlock;

        ProposalVote storage vote = proposalVotes.push();
        vote.rewardRate = rewardRate;

        emit Propose(msg.sender, proposalId, title, content);
    }

    function councilVote(uint256 proposalId, bool yesOrNo) public {
        // check period
        ProposalData storage proposalData = proposalDatas[proposalId];
        require(block.timestamp <= proposalData.councilReviewFinish, "not period");

        // prevent duplicate
        ProposalVote storage vote = proposalVotes[proposalId];
        require(vote.councilVotes[msg.sender] == false, "duplicate");

        IGovernance.CouncilMember[] memory members = getCouncilMembers(msg.sender);

        vote.councilVotes[msg.sender] = true;
        vote.councilYesOrNoVotes[msg.sender] = yesOrNo;

        if (yesOrNo == true) {
            proposalData.councilYes += members.length;
        } else {
            proposalData.councilNo += members.length;
        }

        for (uint256 i = 0; i < members.length; i++) {
            if (yesOrNo == true) {
                proposalData.councilYesUsers.push(members[i]);
            } else {
                proposalData.councilNoUsers.push(members[i]);
            }

            vote.voteCouncilMembers.push(members[i]);

            emit CouncilVote(proposalId, members[i].user, members[i].country, members[i].text, yesOrNo);
        }

        if (proposalData.councilYes >= needCouncilMemberAgreeCnt) {
            proposalData.state = ProposalState.UserVote;
            proposalData.councilReviewFinish = block.timestamp;
            emit FinishCouncilVote(proposalId, proposalData.state);
        } else if (proposalData.councilNo > councilMembers.length - needCouncilMemberAgreeCnt) {
            proposalData.state = ProposalState.Drop;
            proposalData.councilReviewFinish = block.timestamp;
            emit FinishCouncilVote(proposalId, proposalData.state);
        }
    }

    function finishCouncilVote(uint256 proposalId) public onlyAdmin {
        // check period
        ProposalData storage proposalData = proposalDatas[proposalId];
        require(block.timestamp > proposalData.councilReviewFinish, "not period");

        // check state
        require(proposalData.state == ProposalState.CouncilReview, "not state CouncilReview");

        if (proposalData.councilYes >= needCouncilMemberAgreeCnt) {
            proposalData.state = ProposalState.UserVote;
        } else {
            proposalData.state = ProposalState.Drop;
        }

        emit FinishCouncilVote(proposalId, proposalData.state);
    }

    function userVote(
        uint256 proposalId,
        bool yesOrNo,
        uint256 tokenCount
    ) public {
        //check state
        ProposalData storage proposalData = proposalDatas[proposalId];
        require(proposalData.state == ProposalState.UserVote, "not state UserVote");

        //check period
        require(
            block.timestamp > proposalData.councilReviewFinish && block.timestamp <= proposalData.userVoteFinish,
            "not period"
        );

        ProposalVote storage vote = proposalVotes[proposalId];

        govToken.transferFrom(msg.sender, address(this), tokenCount);

        if (yesOrNo == true) {
            if (vote.yesTokenStartBlocks[msg.sender] > 0) {
                uint256 reward = getReward(
                    vote.yesTokens[msg.sender],
                    vote.yesTokenStartBlocks[msg.sender],
                    block.number
                );

                vote.yesTokenRewards[msg.sender] = vote.yesTokenRewards[msg.sender] + reward;
            }
            vote.yesTokenStartBlocks[msg.sender] = block.number;

            proposalData.userYes = proposalData.userYes + tokenCount;
            vote.yesTokens[msg.sender] = vote.yesTokens[msg.sender] + tokenCount;
        } else {
            if (vote.noTokenStartBlocks[msg.sender] > 0) {
                uint256 reward = getReward(
                    vote.noTokens[msg.sender],
                    vote.noTokenStartBlocks[msg.sender],
                    block.number
                );

                vote.noTokenRewards[msg.sender] = vote.noTokenRewards[msg.sender] + reward;
            }
            vote.noTokenStartBlocks[msg.sender] = block.number;

            proposalData.userNo = proposalData.userNo + tokenCount;
            vote.noTokens[msg.sender] = vote.noTokens[msg.sender] + tokenCount;
        }

        vote.userVoteInfos.push(UserVoteInfo({user: msg.sender, yesOrNo: yesOrNo, tokenCnt: tokenCount}));

        vote.lockFinishBlocks[msg.sender] = block.number + proposalData.lockupTokenBlock;

        emit UserVote(proposalId, msg.sender, yesOrNo, tokenCount);
    }

    function finishUserVote(uint256 proposalId) public onlyAdmin {
        //check period
        ProposalData storage proposalData = proposalDatas[proposalId];
        require(proposalData.state == ProposalState.UserVote, "not state UserVote");

        //check state
        require(block.timestamp > proposalData.userVoteFinish, "not period");

        if (proposalData.userYes > proposalData.userNo) {
            proposalData.isUserVoteWin = true;
            proposalData.state = ProposalState.TeamReview;
        } else {
            proposalData.isUserVoteWin = false;
            proposalData.state = ProposalState.Complete;
        }

        emit FinishUserVote(proposalId, proposalData.state, proposalData.isUserVoteWin);
    }

    function writeTeamReview(uint256 proposalId, string memory review) public onlyAdmin {
        ProposalData storage proposaDatal = proposalDatas[proposalId];
        require(proposaDatal.state == ProposalState.TeamReview, "not state TeamReview");

        proposaDatal.teamReview = review;

        proposaDatal.state = ProposalState.Complete;

        emit WriteTeamReview(proposalId, review);
    }

    function claimVotedToken(uint256 proposalId) public {
        //check period
        ProposalData storage proposalData = proposalDatas[proposalId];
        require(block.timestamp > proposalData.userVoteFinish, "not period");

        ProposalVote storage vote = proposalVotes[proposalId];

        require(block.number >= vote.lockFinishBlocks[msg.sender], "locked token");

        uint256 votedToken = vote.yesTokens[msg.sender] + vote.noTokens[msg.sender];

        uint256 claimableToken = votedToken - vote.claimedTokens[msg.sender];

        require(claimableToken > 0, "no claimableToken");

        uint256 reward = vote.yesTokenRewards[msg.sender] +
            getReward(
                vote.yesTokens[msg.sender],
                vote.yesTokenStartBlocks[msg.sender],
                vote.lockFinishBlocks[msg.sender]
            ) +
            vote.noTokenRewards[msg.sender] +
            getReward(
                vote.noTokens[msg.sender],
                vote.noTokenStartBlocks[msg.sender],
                vote.lockFinishBlocks[msg.sender]
            );

        vote.claimedTokens[msg.sender] = votedToken;
        vote.claimedTokenRewards[msg.sender] = reward;

        govToken.transfer(msg.sender, claimableToken);
        govToken.transferFrom(rewardBank, msg.sender, reward);

        emit ClaimVotedToken(proposalId, msg.sender, claimableToken, reward);
    }

    function emergencyWithdraw(uint256 amount) public onlyAdmin {
        govToken.transfer(msg.sender, amount);
    }

    // For test
    function updateProposalFinishTime(
        uint256 proposalId,
        uint256 councilReviewFinish,
        uint256 userVoteFinish
    ) public onlyAdmin {
        ProposalData storage proposalData = proposalDatas[proposalId];
        proposalData.councilReviewFinish = councilReviewFinish;
        proposalData.userVoteFinish = userVoteFinish;
    }

    function updateProposalState(uint256 proposalId, ProposalState state) public onlyAdmin {
        ProposalData storage proposalData = proposalDatas[proposalId];
        proposalData.state = state;
    }

    /***************************************************************
        public view functions
    ***************************************************************/

    function getProposalCount() public view returns (uint256) {
        return proposals.length;
    }

    function getProposal(uint256 proposalId)
        public
        view
        returns (
            Proposal memory,
            ProposalData memory,
            IGovernance.CouncilMember[] memory,
            uint256
        )
    {
        return (
            proposals[proposalId],
            proposalDatas[proposalId],
            proposalVotes[proposalId].voteCouncilMembers,
            councilMembers.length
        );
    }

    function getCouncilInfo(uint256 proposalId, address councilMember)
        public
        view
        returns (
            uint256 ticketCount,
            bool voted,
            bool yesOrNo
        )
    {
        ticketCount = getCouncilTicketCount(councilMember);
        voted = proposalVotes[proposalId].councilVotes[councilMember];
        yesOrNo = proposalVotes[proposalId].councilYesOrNoVotes[councilMember];
    }

    function getProposalVote(address voter, uint256 proposalId)
        public
        view
        returns (
            uint256 yesToken,
            uint256 yesRewardToken,
            uint256 noToken,
            uint256 noRewardToken,
            uint256 claimedToken,
            uint256 claimedRewardToken,
            uint256 lockFinishBlock
        )
    {
        ProposalVote storage vote = proposalVotes[proposalId];

        yesToken = vote.yesTokens[voter];
        yesRewardToken =
            vote.yesTokenRewards[voter] +
            getReward(yesToken, vote.yesTokenStartBlocks[voter], block.number);

        noToken = vote.noTokens[voter];
        noRewardToken = vote.noTokenRewards[voter] + getReward(noToken, vote.noTokenStartBlocks[voter], block.number);

        claimedToken = vote.claimedTokens[voter];
        claimedRewardToken = vote.claimedTokenRewards[voter];

        lockFinishBlock = vote.lockFinishBlocks[voter];
    }

    function getUserVotes(
        uint256 proposalId,
        uint256 offset,
        uint256 count
    )
        public
        view
        returns (
            address[] memory users,
            bool[] memory yesOrNos,
            uint256[] memory tokenCounts
        )
    {
        ProposalVote storage vote = proposalVotes[proposalId];
        uint256 voteInfoLength = vote.userVoteInfos.length;

        uint256 workCount = count;
        if (offset + count > voteInfoLength) {
            workCount = voteInfoLength - offset;
        }

        users = new address[](workCount);
        yesOrNos = new bool[](workCount);
        tokenCounts = new uint256[](workCount);

        for (uint256 i = 0; i < workCount; i++) {
            uint256 length = voteInfoLength - 1 - offset - i;
            users[i] = vote.userVoteInfos[length].user;
            yesOrNos[i] = vote.userVoteInfos[length].yesOrNo;
            tokenCounts[i] = vote.userVoteInfos[length].tokenCnt;
        }
    }

    function getCouncilMembers() public view returns (IGovernance.CouncilMember[] memory) {
        return councilMembers;
    }

    function getInfo()
        public
        view
        returns (
            uint256 _seq,
            ERC20Burnable _govToken,
            uint256 _proposePrice,
            uint256 _councilReviewPeriod,
            uint256 _userVotePeriod,
            uint256 _needCouncilMemberAgreeCnt,
            uint256 _lockupTokenBlock,
            uint256 _rewardRate,
            address _rewardBank,
            uint256 _councilFinish
        )
    {
        _seq = seq;
        _govToken = govToken;
        _proposePrice = proposePrice;
        _councilReviewPeriod = councilReviewPeriod;
        _userVotePeriod = userVotePeriod;
        _needCouncilMemberAgreeCnt = needCouncilMemberAgreeCnt;
        _lockupTokenBlock = lockupTokenBlock;
        _rewardRate = rewardRate;
        _rewardBank = rewardBank;
        _councilFinish = councilFinish;
    }

    /***************************************************************
        private view functions
    ***************************************************************/

    function getCouncilTicketCount(address councilMember) private view returns (uint256) {
        uint256 result;
        for (uint256 i = 0; i < councilMembers.length; i++) {
            if (councilMembers[i].user == councilMember) {
                result += 1;
            }
        }

        return result;
    }

    function getCouncilMembers(address councilMember) private view returns (IGovernance.CouncilMember[] memory) {
        uint256 count = getCouncilTicketCount(councilMember);
        IGovernance.CouncilMember[] memory result = new IGovernance.CouncilMember[](count);

        uint256 index;
        for (uint256 i = 0; i < councilMembers.length; i++) {
            if (councilMembers[i].user == councilMember) {
                result[index] = councilMembers[i];
                index++;
            }
        }

        return result;
    }

    function getReward(
        uint256 amount,
        uint256 startBlock,
        uint256 finishBlock
    ) private view returns (uint256) {
        if (amount == 0) return 0;

        uint256 period = finishBlock - startBlock;

        return (((amount * rewardRate) / 1000) * period) / oneYear;
    }
}
