// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../utils/TokenHelper.sol";
import "../utils/Withdrawable.sol";
import "./DistrictViewer.sol";
import "./DistrictInfo.sol";

contract ExploringV2 is Ownable, AccessControlEnumerable, TokenHelper, Withdrawable, Pausable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    struct Country {
        string name;
        uint256 layCost;
        uint256 orbCost;
    }

    struct ExploringInfo {
        address account;
        string countryName;
        uint256 exploredBlockNumber;
        uint256 seedFirst;
        uint256 seedSecondBlockNumber;
        string seedSecondBlockHash;
        uint256 receiveTokenId;
    }

    struct ExploringStatus {
        uint256 waitTime;
        uint256 communityRate;
        Country[] countries;
        uint256[] maxCounts;
        uint256[] remainCounts;
        uint256[] exploredBlockNumbers;
    }

    address public lay;
    address public orb;
    address public districtInfo;
    address public district;
    address public communityTreasury;
    address public districtViewer;

    Country[] public countries;
    mapping(string => uint256) private countryIndexes;
    mapping(string => bool) private existCountry;

    mapping(string => uint256[]) private countryPool;
    mapping(uint256 => uint256) private countryPoolIndexes;
    mapping(string => uint256) private countryMaxCount;
    mapping(string => uint256) private countryRemainCount;

    ExploringInfo[] public exploringInfos;
    mapping(address => mapping(string => uint256)) private exploringInfoIndexes;
    mapping(address => mapping(string => bool)) private existExploringInfo;

    uint256 public waitTime;
    uint256 public communityRate;
    uint256 public referralRate;
    uint256 public paybackRate;
    uint256 public startBlockNumber;

    event AddDistrict(string indexed country, uint256 indexed tokenId);
    event Explored(address indexed account, string indexed country, uint256 layCost, uint256 orbCost);
    event ClaimExploring(address indexed account, string indexed country, uint256 tokenId);
    event EmergencyWithdraw(address indexed user, uint256 workCnt);
    event AddBlockHash(
        address indexed user,
        string indexed country,
        uint256 blockNumber,
        string blockHash,
        uint256 receiveTokenId
    );
    event Referral(address indexed kip17, address indexed from, address indexed to, uint256 amounts);
    event Payback(address indexed kip17, address indexed account, uint256 amounts);

    constructor(
        address _districtViewer,
        address _districtInfo,
        address _district,
        address _lay,
        address _orb,
        address _communityTreasury,
        uint256 _communityRate,
        uint256 _referralRate,
        uint256 _paybackRate
    ) {
        _setupRole(WITHDRAWER_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());

        districtInfo = _districtInfo;
        district = _district;
        lay = _lay;
        orb = _orb;
        communityTreasury = _communityTreasury;
        districtViewer = _districtViewer;
        communityRate = _communityRate;
        referralRate = _referralRate;
        paybackRate = _paybackRate;
    }

    function setContract(
        address _districtInfo,
        address _district,
        address _lay,
        address _orb,
        address _communityTreasury
    ) public onlyOwner {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setContract] must have DEFAULT_ADMIN_ROLE");
        districtInfo = _districtInfo;
        district = _district;
        lay = _lay;
        orb = _orb;
        communityTreasury = _communityTreasury;
    }

    function setCommunityTreasury(address value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setCommunityTreasury] must have DEFAULT_ADMIN_ROLE");
        communityTreasury = value;
    }

    function setDistrictInfo(address value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setDistrictInfo] must have DEFAULT_ADMIN_ROLE");
        districtInfo = value;
    }

    function setLay(address value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setLay] must have DEFAULT_ADMIN_ROLE");
        lay = value;
    }

    function setDistrict(address value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setDistrict] must have DEFAULT_ADMIN_ROLE");
        district = value;
    }

    function setOrb(address value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setOrb] must have DEFAULT_ADMIN_ROLE");
        orb = value;
    }

    function setDistrictViewer(address value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setDistrictViewer] must have DEFAULT_ADMIN_ROLE");
        districtViewer = value;
    }

    function setReferralRate(uint256 value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setReferralRate] must have DEFAULT_ADMIN_ROLE");
        referralRate = value;
    }

    function setPaybackRate(uint256 value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setPaybackRate] must have DEFAULT_ADMIN_ROLE");
        paybackRate = value;
    }

    function setCommunityRate(uint256 value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setCommunityRate] must have DEFAULT_ADMIN_ROLE");
        communityRate = value;
    }

    function pause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "[pause] must have PAUSER_ROLE");
        _pause();
    }

    function unpause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "[unpause] must have PAUSER_ROLE");
        _unpause();
    }

    function setVariable(
        uint256 _waitTime,
        uint256 _communityRate,
        uint256 _startBlockNumber
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[setVariable] must have DEFAULT_ADMIN_ROLE");
        waitTime = _waitTime;
        communityRate = _communityRate;
        startBlockNumber = _startBlockNumber;
    }

    function addDistrict(uint256 tokenId) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[addDistrict] must have DEFAULT_ADMIN_ROLE");

        string memory country = DistrictInfo(districtInfo).getAttribute(tokenId, "Country");

        IERC721(district).transferFrom(msg.sender, address(this), tokenId);
        countryPool[country].push(tokenId);
        countryPoolIndexes[tokenId] = countryPool[country].length - 1;

        countryMaxCount[country] = countryMaxCount[country] + 1;
        countryRemainCount[country] = countryRemainCount[country] + 1;
        emit AddDistrict(country, tokenId);
    }

    function addCountries(Country[] memory _countries) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "[addCountries] must have DEFAULT_ADMIN_ROLE");
        for (uint256 i = 0; i < _countries.length; i++) {
            if (existCountry[_countries[i].name] == false) {
                countries.push(_countries[i]);

                countryIndexes[_countries[i].name] = countries.length - 1;

                existCountry[_countries[i].name] = true;
            }
        }
    }

    function forceWithdraw(
        address erc721,
        address to,
        uint256 id
    ) public {
        super.withdraw(erc721, to, id);
    }

    function withdraw(
        address erc721,
        address to,
        uint256 id
    ) public override {
        require(hasRole(WITHDRAWER_ROLE, _msgSender()), "[addDistrict] must have DEFAULT_ADMIN_ROLE");

        (bool check, bytes memory data) = address(districtInfo).staticcall(
            abi.encodeWithSignature("getAttribute(uint256,string)", id, "Country")
        );
        require(check == true, "[addDistrict] getAttribute");

        string memory country = abi.decode(data, (string)); //districtInfo.getAttribute(tokenId, "Country");

        removeDistrict(country, id);

        super.withdraw(erc721, to, id);
    }

    function addBlockHash(uint256 index, string memory blockHash) public {
        require(hasRole(WITHDRAWER_ROLE, _msgSender()), "[addBlockHash] must have DEFAULT_ADMIN_ROLE");
        require(index + 1 <= exploringInfos.length, "invalid index");
        ExploringInfo storage exploringInfo = exploringInfos[index];
        require(exploringInfo.seedSecondBlockNumber < block.number, "seedSecondblockNumber is not ready");

        exploringInfo.seedSecondBlockHash = blockHash;

        uint256[] storage districts = countryPool[exploringInfo.countryName];
        uint256 districtIndex = getRandom(exploringInfo.seedFirst, exploringInfo.seedSecondBlockHash, districts.length);
        exploringInfo.receiveTokenId = districts[districtIndex];

        removeDistrict(exploringInfo.countryName, exploringInfo.receiveTokenId);

        emit AddBlockHash(
            exploringInfo.account,
            exploringInfo.countryName,
            exploringInfo.seedSecondBlockNumber,
            exploringInfo.seedSecondBlockHash,
            exploringInfo.receiveTokenId
        );
    }

    function getExploringInfoLength() public view returns (uint256) {
        return exploringInfos.length;
    }

    function _exploring(
        address account,
        string memory country,
        uint256 layCost,
        uint256 orbCost,
        address referral,
        uint256 explored
    ) private {
        require(block.number >= startBlockNumber, "start blocknumber");

        require(countryRemainCount[country] > 0, "No district");

        countryRemainCount[country] = countryRemainCount[country] - 1;

        mapping(string => bool) storage _existExploringInfo = existExploringInfo[account];

        require(_existExploringInfo[country] == false, "already exploring the country");

        //require(oldLayCost == layCost && oldOrbCost == orbCost, "Mismatch orb & lay cost");

        _existExploringInfo[country] = true;

        mapping(string => uint256) storage _exploringInfoIndexes = exploringInfoIndexes[account];

        uint256 seed = getSeed();

        exploringInfos.push(
            ExploringInfo({
                account: account,
                countryName: country,
                exploredBlockNumber: explored,
                seedFirst: seed,
                seedSecondBlockNumber: explored + 120,
                seedSecondBlockHash: "",
                receiveTokenId: 0
            })
        );

        _exploringInfoIndexes[country] = exploringInfos.length - 1;

        uint256 layTreasury = (layCost * communityRate) / 100;
        uint256 orbTreasury = (orbCost * communityRate) / 100;

        uint256 layBurn = layCost - layTreasury;
        uint256 orbBurn = orbCost - orbTreasury;

        // 100000000000000000000
        // 10000000000000000000
        // 90000000000000000000
        if (referral != address(0)) {
            if (referralRate > 0) {
                layBurn = layBurn - _referral(lay, account, referral, layCost);
                orbBurn = orbBurn - _referral(orb, account, referral, orbCost);
            }

            if (paybackRate > 0) {
                layBurn = layBurn - _payback(lay, account, layCost);
                orbBurn = orbBurn - _payback(orb, account, orbCost);
            }
        }

        if (layTreasury > 0) {
            _transfer(lay, communityTreasury, layTreasury);
        }
        if (orbTreasury > 0) {
            _transfer(orb, communityTreasury, orbTreasury);
        }

        if (layBurn > 0) {
            _burn(lay, layBurn);
        }

        if (orbBurn > 0) {
            _burn(orb, orbBurn);
        }

        emit Explored(account, country, layCost, orbCost);
    }

    function _referral(
        address erc20,
        address from,
        address to,
        uint256 amounts
    ) private returns (uint256) {
        uint256 cost = (amounts * referralRate) / 100;
        _transfer(erc20, to, cost);
        emit Referral(lay, from, to, cost);
        return cost;
    }

    function _payback(
        address erc20,
        address to,
        uint256 amounts
    ) private returns (uint256) {
        uint256 cost = (amounts * paybackRate) / 100;
        _transfer(erc20, to, cost);
        emit Payback(lay, to, cost);
        return cost;
    }

    function exploring(string memory country, address referral) public whenNotPaused {
        exploringTo(msg.sender, country, referral);
    }

    function exploringTo(
        address account,
        string memory country,
        address referral
    ) public whenNotPaused {
        if (referral != address(0)) {
            require(account != referral, "[Exploring] self referral");
            require(
                DistrictViewer(districtViewer).balanceOf(referral) > 0,
                "[Exploring] referral address havnt district"
            );
        }
        uint256 countryIndex = countryIndexes[country];
        Country storage gCountry = countries[countryIndex];

        uint256 layCost = gCountry.layCost;
        uint256 orbCost = gCountry.orbCost;

        _transferFrom(lay, msg.sender, address(this), layCost);
        _transferFrom(orb, msg.sender, address(this), orbCost);

        _exploring(account, country, layCost, orbCost, referral, block.number);
    }

    function forceExploring(address account, string memory country) public onlyOwner {
        _exploring(account, country, 0, 0, address(0), block.number);
    }

    function forceExploringWithBlockNumber(
        address account,
        string memory country,
        uint256 blockNumber
    ) public onlyOwner {
        _exploring(account, country, 0, 0, address(0), blockNumber);
    }

    function claim(string memory country) public {
        claimFrom(msg.sender, country);
    }

    function claimFrom(address account, string memory country) public {
        mapping(string => bool) storage _existExploringInfo = existExploringInfo[account];

        require(_existExploringInfo[country] == true, "Does not exist Exploring-Ticket");

        mapping(string => uint256) storage _exploringInfoIndexes = exploringInfoIndexes[account];

        ExploringInfo storage exploringInfo = exploringInfos[_exploringInfoIndexes[country]];

        require(exploringInfo.receiveTokenId > 0, "no receiveTokenId");

        require(block.number >= exploringInfo.exploredBlockNumber + waitTime, "Not ready");

        IERC721(district).transferFrom(address(this), account, exploringInfo.receiveTokenId);

        removeExploringInfoIndex(country);

        emit ClaimExploring(account, country, exploringInfo.receiveTokenId);
    }

    function removeExploringInfoIndex(string memory country) private {
        mapping(string => uint256) storage _exploringInfoIndexes = exploringInfoIndexes[msg.sender];
        mapping(string => bool) storage _existExploringInfo = existExploringInfo[msg.sender];

        delete _exploringInfoIndexes[country];
        delete _existExploringInfo[country];
    }

    function getSeed() private view returns (uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.difficulty +
                        ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) +
                        block.gaslimit +
                        ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) +
                        block.number
                )
            )
        );

        return seed;
    }

    function removeDistrict(string memory country, uint256 tokenId) private {
        uint256[] storage districts = countryPool[country];

        uint256 index = countryPoolIndexes[tokenId];
        uint256 lastIndex = districts.length - 1;

        if (index != lastIndex) {
            uint256 temp = districts[lastIndex];
            countryPoolIndexes[temp] = index;
            districts[index] = temp;
        }

        districts.pop();
        delete countryPoolIndexes[tokenId];
    }

    function getStatus() public view returns (ExploringStatus memory) {
        uint256[] memory maxCounts = new uint256[](countries.length);
        uint256[] memory remainCounts = new uint256[](countries.length);
        uint256[] memory exploredBlockNumbers = new uint256[](countries.length);

        for (uint256 i = 0; i < countries.length; i++) {
            string memory countryName = countries[i].name;
            maxCounts[i] = countryMaxCount[countryName];
            remainCounts[i] = countryRemainCount[countryName];

            if (existExploringInfo[msg.sender][countryName] == true) {
                exploredBlockNumbers[i] = exploringInfos[exploringInfoIndexes[msg.sender][countryName]]
                    .exploredBlockNumber;
            }
        }

        ExploringStatus memory result = ExploringStatus({
            waitTime: waitTime,
            communityRate: communityRate,
            countries: countries,
            maxCounts: maxCounts,
            remainCounts: remainCounts,
            exploredBlockNumbers: exploredBlockNumbers
        });

        return result;
    }

    function exploringAccount() public view returns (address[] memory) {
        uint256 totalCount;

        for (uint256 i = 0; i < exploringInfos.length; i++) {
            if (exploringInfos[i].receiveTokenId == 0) {
                totalCount++;
            }
        }

        address[] memory result = new address[](totalCount);

        uint256 index;
        for (uint256 i = 0; i < exploringInfos.length; i++) {
            if (exploringInfos[i].receiveTokenId == 0) {
                result[index];
                index++;
            }
        }

        return result;
    }

    function getRandom(
        uint256 seedFirst,
        string memory blockHash,
        uint256 length
    ) private pure returns (uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(seedFirst, blockHash)));

        return seed % length;
    }
}
