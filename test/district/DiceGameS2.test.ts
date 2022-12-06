import { expect } from 'chai';
import { ethers, waffle } from 'hardhat';

import OrbArtifact from '../../artifacts/contracts/tokens/Orb.sol/Orb.json';
import LayArtifact from '../../artifacts/contracts/tokens/Lay.sol/Lay.json';
import DistrictArtifact from '../../artifacts/contracts/nft/District.sol/District.json';
import DistrictInfoArtifact from '../../artifacts/contracts/district/DistrictInfo.sol/DistrictInfo.json';
import DiceGameS2Artifact from '../../artifacts/contracts/district/DiceGameS2.sol/DiceGameS2.json';
import DistrictStakingArtifact from '../../artifacts/contracts/district/DistrictStaking.sol/DistrictStaking.json';

import { Lay } from '../../typechain/Lay';
import { Orb } from '../../typechain/Orb';
import { District } from '../../typechain/District';
import { DistrictInfo } from '../../typechain/DistrictInfo';
import { DiceGameS2 } from '../../typechain/DiceGameS2';
import { DistrictStaking } from '../../typechain/DistrictStaking';

import { mine } from '../utils/blockchain';
import { BigNumber } from '@ethersproject/bignumber';
import { ContractReceipt } from 'ethers';

const { deployContract } = waffle;

describe('DiceGameS2', () => {
  let orb: Orb;
  let lay: Lay;
  let district: District;
  let districtInfo: DistrictInfo;
  let diceGameS2: DiceGameS2;
  let districtStaking: DistrictStaking;

  const provider = waffle.provider;
  const [owner, admin, govTreasury, other0, other1, other2] =
    provider.getWallets();
  const initSupply: BigNumber = BigNumber.from(10).pow(40);

  const tiers: number[] = [1, 2, 3];

  const rewards: BigNumber[] = [
    BigNumber.from(10).pow(18).mul(1),
    BigNumber.from(10).pow(17).mul(6),
    BigNumber.from(10).pow(17).mul(2),
  ];

  const levels: number[] = [1, 2, 3, 4, 5, 6];

  const multiplies: number[] = [0, 50, 150, 300, 500, 1000];
  const initLay: BigNumber = BigNumber.from(10).pow(30);
  interface Reward {
    total: BigNumber;
    tax: BigNumber;
    user: BigNumber;
  }
  const rewardMap: { [k: number]: { [k: number]: Reward } } = {};
  const taxRate = 20;

  before(async () => {
    for (let i = 0; i < tiers.length; i++) {
      rewardMap[tiers[i]] = {};
      for (let j = 0; j < levels.length; j++) {
        rewardMap[tiers[i]][levels[j]] = {
          total: BigNumber.from(0),
          tax: BigNumber.from(0),
          user: BigNumber.from(0),
        };
        rewardMap[tiers[i]][levels[j]].total = rewards[i].add(
          rewards[i].mul(multiplies[j]).div(100),
        );
        rewardMap[tiers[i]][levels[j]].tax = rewardMap[tiers[i]][
          levels[j]
        ].total
          .mul(taxRate)
          .div(100);
        rewardMap[tiers[i]][levels[j]].user = rewardMap[tiers[i]][
          levels[j]
        ].total.sub(rewardMap[tiers[i]][levels[j]].tax);
      }
    }

    districtInfo = (await deployContract(
      owner,
      DistrictInfoArtifact,
      [],
    )) as DistrictInfo;
    await makeDistrictInfo();
  });

  beforeEach(async () => {
    lay = (await deployContract(owner, LayArtifact, ['', ''])) as Lay;
    orb = (await deployContract(owner, OrbArtifact, ['', ''])) as Orb;
    district = (await deployContract(owner, DistrictArtifact, [
      'KlayCity District',
      'District',
      'https:dummy.com/',
    ])) as District;

    districtStaking = (await deployContract(owner, DistrictStakingArtifact, [
      district.address,
      districtInfo.address,
      0,
    ])) as DistrictStaking;

    diceGameS2 = (await deployContract(owner, DiceGameS2Artifact, [
      lay.address,
      district.address,
      districtInfo.address,
      govTreasury.address,
      districtStaking.address,
    ])) as DiceGameS2;

    //dummy
    await district.mint(other0.address);

    await district.mint(other0.address);
    await district.mint(other1.address);
    await district.mint(other1.address);
    await district.mint(other2.address);
    await district.mint(other2.address);
    await district.mint(other2.address);

    // send lay to dicegame
    await lay.mint(owner.address, initLay);
    await lay.transfer(diceGameS2.address, initLay);

    // give admin role
    await districtStaking.addAdmin(diceGameS2.address);
    await diceGameS2.addAdmin(admin.address);
    await diceGameS2.addAdmin(diceGameS2.address);

    await diceGameS2.setReward(tiers, rewards, levels, multiplies);
    await diceGameS2.setWaitTime(0);

    // approve all
    const approvedAll = await district.isApprovedForAll(
      other0.address,
      districtStaking.address,
    );
    if (approvedAll == false) {
      await district
        .connect(other0)
        .setApprovalForAll(districtStaking.address, true);
    }
    await district
      .connect(other1)
      .setApprovalForAll(districtStaking.address, true);
    await district
      .connect(other2)
      .setApprovalForAll(districtStaking.address, true);
  });

  it('simple play', async () => {
    const minTier = await diceGameS2.minTier();
    expect(minTier).to.be.equal(3);

    const maxLevel = await diceGameS2.maxLevel();
    expect(maxLevel).to.be.equal(6);

    const rewardTable = await diceGameS2.getReward();
    expect(rewardTable[0].length).to.be.equal(3);
    expect(rewardTable[1].length).to.be.equal(6);

    await simplePlay();
  });

  it('dice validation', async () => {
    await expect(diceGameS2.connect(other0).getLays([1])).to.reverted;
    await expect(diceGameS2.connect(other0).getLays([5])).to.reverted;

    await districtStaking.connect(other0).stake(1);

    let [stakingInfo, existStakingInfo] = await districtStaking.getStakingInfo(
      1,
    );
    expect(existStakingInfo).to.be.equal(true);
    expect(stakingInfo.stakedBlockNumber > BigNumber.from(0)).to.be.equal(true);

    await diceGameS2.setWaitTime(86400);

    await expect(diceGameS2.connect(other0).getLays([1])).to.reverted;

    await diceGameS2.setWaitTime(0);

    await diceGameS2.connect(other0).getLays([1]);

    [stakingInfo, existStakingInfo] = await districtStaking.getStakingInfo(1);
    expect(existStakingInfo).to.be.equal(true);
    expect(stakingInfo.playBlockNumber > BigNumber.from(0)).to.be.equal(true);

    await diceGameS2.setWaitTime(86400);

    await expect(diceGameS2.connect(other0).getLays([1])).to.reverted;

    await diceGameS2.setWaitTime(0);

    await diceGameS2.connect(other0).getLays([1]);
  });

  it('dice user reward validation', async () => {
    await districtStaking.connect(other0).stake(1);

    await districtStaking.connect(other1).stake(2);
    await districtStaking.connect(other1).stake(3);

    await districtStaking.connect(other2).stake(4);
    await districtStaking.connect(other2).stake(5);
    await districtStaking.connect(other2).stake(6);

    let other0Balance: BigNumber = BigNumber.from(0);
    let other1Balance: BigNumber = BigNumber.from(0);
    let other2Balance: BigNumber = BigNumber.from(0);

    await diceGameS2.connect(other0).getLays([1]);
    other0Balance = other0Balance.add(rewardMap[1][1].user);
    let userBalances = await getUserBalances();
    expect(userBalances[0]).to.be.equal(other0Balance);

    await diceGameS2.connect(other0).getLays([1]);
    other0Balance = other0Balance.add(rewardMap[1][1].user);
    userBalances = await getUserBalances();
    expect(userBalances[0]).to.be.equal(other0Balance);

    await diceGameS2.connect(other0).getLays([1]);
    other0Balance = other0Balance.add(rewardMap[1][1].user);
    userBalances = await getUserBalances();
    expect(userBalances[0]).to.be.equal(other0Balance);

    await diceGameS2.connect(other1).getLays([2]);
    other1Balance = other1Balance.add(rewardMap[1][2].user);
    userBalances = await getUserBalances();
    expect(userBalances[1]).to.be.equal(other1Balance);

    await diceGameS2.connect(other1).getLays([2]);
    other1Balance = other1Balance.add(rewardMap[1][2].user);
    userBalances = await getUserBalances();
    expect(userBalances[1]).to.be.equal(other1Balance);

    await diceGameS2.connect(other1).getLays([2]);
    other1Balance = other1Balance.add(rewardMap[1][2].user);
    userBalances = await getUserBalances();
    expect(userBalances[1]).to.be.equal(other1Balance);

    await diceGameS2.connect(other2).getLays([4]);
    other2Balance = other2Balance.add(rewardMap[2][4].user);
    userBalances = await getUserBalances();
    expect(userBalances[2]).to.be.equal(other2Balance);

    await diceGameS2.connect(other2).getLays([4]);
    other2Balance = other2Balance.add(rewardMap[2][4].user);
    userBalances = await getUserBalances();
    expect(userBalances[2]).to.be.equal(other2Balance);

    await diceGameS2.connect(other2).getLays([4]);
    other2Balance = other2Balance.add(rewardMap[2][4].user);
    userBalances = await getUserBalances();
    expect(userBalances[2]).to.be.equal(other2Balance);

    // remain district
    await diceGameS2.connect(other1).getLays([3]);
    other1Balance = other1Balance.add(rewardMap[1][3].user);
    userBalances = await getUserBalances();
    expect(userBalances[1]).to.be.equal(other1Balance);

    await diceGameS2.connect(other2).getLays([5]);
    other2Balance = other2Balance.add(rewardMap[3][5].user);
    userBalances = await getUserBalances();
    expect(userBalances[2]).to.be.equal(other2Balance);

    await diceGameS2.connect(other2).getLays([6]);
    other2Balance = other2Balance.add(rewardMap[3][6].user);
    userBalances = await getUserBalances();
    expect(userBalances[2]).to.be.equal(other2Balance);
  });

  async function makeDistrictInfo() {
    await districtInfo['setAttribute(uint256,string[],string[])'](
      1,
      ['Country', 'City', 'Tier', 'Level'],
      ['China', 'Beijing', '1', '1'],
    );

    await districtInfo['setAttribute(uint256,string,string)'](
      2,
      'Country',
      'Vatican City',
    );
    await districtInfo['setAttribute(uint256,string,string)'](
      2,
      'City',
      'Vatican',
    );
    await districtInfo['setAttribute(uint256,string,string)'](2, 'Tier', '1');
    await districtInfo['setAttribute(uint256,string,string)'](2, 'Level', '2');

    await districtInfo['setAttribute(uint256,string,string)'](
      3,
      'Country',
      'Korea',
    );
    await districtInfo['setAttribute(uint256,string,string)'](
      3,
      'City',
      'Seoul',
    );
    await districtInfo['setAttribute(uint256,string,string)'](3, 'Tier', '1');
    await districtInfo['setAttribute(uint256,string,string)'](3, 'Level', '3');

    await districtInfo['setAttribute(uint256,string,string)'](
      4,
      'Country',
      'Vatican City',
    );
    await districtInfo['setAttribute(uint256,string,string)'](
      4,
      'City',
      'Vatican',
    );
    await districtInfo['setAttribute(uint256,string,string)'](4, 'Tier', '2');
    await districtInfo['setAttribute(uint256,string,string)'](4, 'Level', '4');

    await districtInfo['setAttribute(uint256,string,string)'](
      5,
      'Country',
      'China',
    );
    await districtInfo['setAttribute(uint256,string,string)'](
      5,
      'City',
      'Beijing',
    );
    await districtInfo['setAttribute(uint256,string,string)'](5, 'Tier', '3');
    await districtInfo['setAttribute(uint256,string,string)'](5, 'Level', '5');

    await districtInfo['setAttribute(uint256,string,string)'](
      6,
      'Country',
      'Korea',
    );
    await districtInfo['setAttribute(uint256,string,string)'](
      6,
      'City',
      'Seoul',
    );
    await districtInfo['setAttribute(uint256,string,string)'](6, 'Tier', '3');
    await districtInfo['setAttribute(uint256,string,string)'](6, 'Level', '6');
  }

  async function getUserBalances() {
    const other0Lay = await lay.balanceOf(other0.address);
    const other1Lay = await lay.balanceOf(other1.address);
    const other2Lay = await lay.balanceOf(other2.address);

    return [other0Lay, other1Lay, other2Lay];
  }

  async function simplePlay() {
    await expect(districtStaking.connect(other0).stake(1))
      .to.emit(districtStaking, 'Stake')
      .withArgs(other0.address, 1);

    await expect(diceGameS2.connect(other0).getLays([1]))
      .to.emit(diceGameS2, 'GetLays')
      .withArgs(other0.address, [1], rewardMap[1][1].user, rewardMap[1][1].tax);

    let other0Lay = await lay.balanceOf(other0.address);
    expect(other0Lay).to.be.equal(rewardMap[1][1].user);

    await expect(diceGameS2.connect(other0).getLays([1]))
      .to.emit(diceGameS2, 'GetLays')
      .withArgs(other0.address, [1], rewardMap[1][1].user, rewardMap[1][1].tax);

    other0Lay = await lay.balanceOf(other0.address);
    expect(other0Lay).to.be.equal(rewardMap[1][1].user.mul(2));

    await expect(districtStaking.connect(other0).unStake(1))
      .to.emit(districtStaking, 'UnStake')
      .withArgs(other0.address, 1);

    await expect(districtStaking.connect(other0).stake(1))
      .to.emit(districtStaking, 'Stake')
      .withArgs(other0.address, 1);

    await districtStaking.connect(other1).stake(2);

    await districtStaking.connect(other1).stake(3);

    await districtStaking.connect(other2).stake(4);
    await districtStaking.connect(other2).stake(5);
    await districtStaking.connect(other2).stake(6);

    const govLay = await lay.balanceOf(govTreasury.address);

    expect(govLay).to.be.equal(rewardMap[1][1].tax.mul(2));
  }
});
