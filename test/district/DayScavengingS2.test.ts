import { expect } from 'chai';
import { ethers, waffle } from 'hardhat';

import OrbArtifact from '../../artifacts/contracts/tokens/Orb.sol/Orb.json';
import LayArtifact from '../../artifacts/contracts/tokens/Lay.sol/Lay.json';
import DistrictArtifact from '../../artifacts/contracts/nft/District.sol/District.json';
import DistrictInfoArtifact from '../../artifacts/contracts/district/DistrictInfo.sol/DistrictInfo.json';
import DistrictStakingArtifact from '../../artifacts/contracts/district/DistrictStaking.sol/DistrictStaking.json';
import ScavengingS2Artifact from '../../artifacts/contracts/district/ScavengingS2.sol/ScavengingS2.json';

import { Lay } from '../../typechain/Lay';
import { Orb } from '../../typechain/Orb';
import { District } from '../../typechain/District';
import { DistrictInfo } from '../../typechain/DistrictInfo';
import { DistrictStaking } from '../../typechain/DistrictStaking';
import { ScavengingS2 } from '../../typechain/ScavengingS2';

import { mine } from '../utils/blockchain';
import { BigNumber } from '@ethersproject/bignumber';
import { ContractReceipt } from 'ethers';

const { deployContract } = waffle;

describe('Day Scavenging', () => {
  let orb: Orb;
  let lay: Lay;
  let district: District;
  let districtInfo: DistrictInfo;
  let districtStaking: DistrictStaking;

  const provider = waffle.provider;
  const [owner, govTreasury, other0, other1, other2, burnPool] =
    provider.getWallets();

  const initSupply: BigNumber = BigNumber.from(10).pow(40);

  const stakingBlockNumber = 50;

  beforeEach(async () => {
    // await ethers.provider.send("hardhat_reset", []);

    lay = (await deployContract(owner, LayArtifact, ['', ''])) as Lay;
    orb = (await deployContract(owner, OrbArtifact, ['', ''])) as Orb;
    district = (await deployContract(owner, DistrictArtifact, [
      'KlayCity District',
      'District',
      'https:dummy.com/',
    ])) as District;
    districtInfo = (await deployContract(
      owner,
      DistrictInfoArtifact,
      [],
    )) as DistrictInfo;
    districtStaking = (await deployContract(owner, DistrictStakingArtifact, [
      district.address,
      districtInfo.address,
      0,
    ])) as DistrictStaking;

    await orb.mint(owner.address, 100000000);

    await lay.mint(owner.address, 100000000);
    await lay.transfer(other0.address, 10000);
    await lay.transfer(other1.address, 10000);
    await lay.transfer(other2.address, 10000);
  });

  it('revert withraw, getReward', async () => {
    const dayScavengingS2 = (await deployContract(owner, ScavengingS2Artifact, [
      orb.address,
      lay.address,
      govTreasury.address,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      1,
      stakingBlockNumber,
      15,
      0,
    ])) as ScavengingS2;

    const duration = 100;
    const totalReward = BigNumber.from(duration * 100);

    let currentBlockNumber = await provider.getBlockNumber();
    const periodStart = currentBlockNumber + 10;

    await dayScavengingS2.setRewardsDuration(periodStart, duration);

    await orb.transfer(dayScavengingS2.address, totalReward);
    await dayScavengingS2.notifyRewardAmount(totalReward);

    await lay.connect(other0).approve(dayScavengingS2.address, 10000);
    await lay.connect(other1).approve(dayScavengingS2.address, 10000);

    currentBlockNumber = await provider.getBlockNumber();
    const remainBlockNumber = periodStart - currentBlockNumber - 1;
    await mine(remainBlockNumber);

    await dayScavengingS2.connect(other0).stake(1);
    await expect(dayScavengingS2.connect(other0).withdraw(1)).to.reverted;
    await expect(dayScavengingS2.connect(other0).getReward()).to.reverted;
  });

  it('check exit', async () => {
    const dayScavengingS2 = (await deployContract(owner, ScavengingS2Artifact, [
      orb.address,
      lay.address,
      govTreasury.address,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      1,
      stakingBlockNumber,
      15,
      0,
    ])) as ScavengingS2;

    const duration = 100;
    const totalReward = BigNumber.from(duration * 100);

    let currentBlockNumber = await provider.getBlockNumber();
    const periodStart = currentBlockNumber + 10;

    await dayScavengingS2.setRewardsDuration(periodStart, duration);

    await orb.transfer(dayScavengingS2.address, totalReward);
    await dayScavengingS2.notifyRewardAmount(totalReward);

    await lay.connect(other0).approve(dayScavengingS2.address, 10000);
    await lay.connect(other1).approve(dayScavengingS2.address, 10000);

    currentBlockNumber = await provider.getBlockNumber();
    const remainBlockNumber = periodStart - currentBlockNumber - 1;
    await mine(remainBlockNumber);

    await dayScavengingS2.connect(other0).stake(1);

    await expect(dayScavengingS2.connect(other0).exit()).to.reverted;

    await mine(stakingBlockNumber);

    await expect(dayScavengingS2.connect(other0).exit())
      .to.emit(dayScavengingS2, 'RewardPaid')
      .withArgs(other0.address, 4335, 765);

    let balance = await orb.balanceOf(other0.address);
    expect(balance).to.be.equal(4335);

    balance = await orb.balanceOf(govTreasury.address);
    expect(balance).to.be.equal(765);
  });

  it('level limit', async () => {
    const dayScavengingS2Level1 = (await deployContract(
      owner,
      ScavengingS2Artifact,
      [
        orb.address,
        lay.address,
        govTreasury.address,
        districtStaking.address,
        districtInfo.address,
        burnPool.address,
        1,
        stakingBlockNumber,
        15,
        1,
      ],
    )) as ScavengingS2;

    const dayScavengingS2Level2 = (await deployContract(
      owner,
      ScavengingS2Artifact,
      [
        orb.address,
        lay.address,
        govTreasury.address,
        districtStaking.address,
        districtInfo.address,
        burnPool.address,
        1,
        stakingBlockNumber,
        15,
        2,
      ],
    )) as ScavengingS2;

    await districtInfo['setAttribute(uint256,string[],string[])'](
      1,
      ['Country', 'City', 'Tier', 'Level'],
      ['South Korea', 'Seoul', '1', '1'],
    );

    await districtInfo['setAttribute(uint256,string[],string[])'](
      2,
      ['Country', 'City', 'Tier', 'Level'],
      ['Japan', 'Tokyo', '1', '2'],
    );

    await districtInfo['setAttribute(uint256,string[],string[])'](
      3,
      ['Country', 'City', 'Tier', 'Level'],
      ['Japan', 'Tokyo', '1', '1'],
    );

    await lay.connect(other0).approve(dayScavengingS2Level1.address, 10000);
    await lay.connect(other0).approve(dayScavengingS2Level2.address, 10000);

    await lay.connect(other1).approve(dayScavengingS2Level1.address, 10000);
    await lay.connect(other1).approve(dayScavengingS2Level2.address, 10000);

    await lay.connect(other2).approve(dayScavengingS2Level1.address, 10000);
    await lay.connect(other2).approve(dayScavengingS2Level2.address, 10000);

    const duration = 100;
    const totalReward = BigNumber.from(duration * 100);

    const currentBlockNumber = await provider.getBlockNumber();
    const periodStart = currentBlockNumber;

    await dayScavengingS2Level1.setRewardsDuration(periodStart, duration);
    await orb.transfer(dayScavengingS2Level1.address, totalReward);
    await dayScavengingS2Level1.notifyRewardAmount(totalReward);

    await dayScavengingS2Level2.setRewardsDuration(periodStart, duration);
    await orb.transfer(dayScavengingS2Level2.address, totalReward);
    await dayScavengingS2Level2.notifyRewardAmount(totalReward);

    //dummy
    await district.mint(other0.address);

    await district.mint(other0.address);
    await district.mint(other0.address);
    await district.mint(other1.address);

    await district
      .connect(other0)
      .setApprovalForAll(districtStaking.address, true);
    await district
      .connect(other1)
      .setApprovalForAll(districtStaking.address, true);

    await districtStaking.connect(other0).stake(1);
    await districtStaking.connect(other0).stake(2);
    await districtStaking.connect(other1).stake(3);

    await dayScavengingS2Level1.connect(other0).stake(1);
    await dayScavengingS2Level2.connect(other0).stake(1);

    await dayScavengingS2Level1.connect(other1).stake(1);
    await expect(
      dayScavengingS2Level2.connect(other1).stake(1),
    ).to.revertedWith('level limit');

    await expect(
      dayScavengingS2Level1.connect(other2).stake(1),
    ).to.revertedWith('level limit');
    await expect(
      dayScavengingS2Level2.connect(other2).stake(1),
    ).to.revertedWith('level limit');
  });

  it('double stake', async () => {
    const dayScavengingS2 = (await deployContract(owner, ScavengingS2Artifact, [
      orb.address,
      lay.address,
      govTreasury.address,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      1,
      stakingBlockNumber,
      15,
      0,
    ])) as ScavengingS2;

    await districtInfo['setAttribute(uint256,string[],string[])'](
      1,
      ['Country', 'City', 'Tier', 'Level'],
      ['South Korea', 'Seoul', '1', '1'],
    );

    await districtInfo['setAttribute(uint256,string[],string[])'](
      2,
      ['Country', 'City', 'Tier', 'Level'],
      ['Japan', 'Tokyo', '1', '2'],
    );

    await lay.connect(other0).approve(dayScavengingS2.address, 10000);
    await lay.connect(other1).approve(dayScavengingS2.address, 10000);

    const duration = 100;
    const totalReward = BigNumber.from(duration * 100);

    const currentBlockNumber = await provider.getBlockNumber();
    const periodStart = currentBlockNumber;

    await dayScavengingS2.setRewardsDuration(periodStart, duration);
    await orb.transfer(dayScavengingS2.address, totalReward);
    await dayScavengingS2.notifyRewardAmount(totalReward);

    //dummy
    await district.mint(other0.address);

    await district.mint(other0.address);
    await district.mint(other1.address);

    await district
      .connect(other0)
      .setApprovalForAll(districtStaking.address, true);
    await district
      .connect(other1)
      .setApprovalForAll(districtStaking.address, true);

    await districtStaking.connect(other0).stake(1);
    await districtStaking.connect(other1).stake(2);

    await dayScavengingS2.connect(other0).stake(1);
    let info = await dayScavengingS2.connect(other0).getInfo(other0.address);
    expect(info[5]).to.be.equal(stakingBlockNumber);

    await dayScavengingS2.connect(other1).stake(1);

    await dayScavengingS2.connect(other0).stake(1);
    info = await dayScavengingS2.connect(other0).getInfo(other0.address);
    expect(info[5]).to.be.equal(stakingBlockNumber);

    await mine(stakingBlockNumber);

    await dayScavengingS2.connect(other0).exit();
    await dayScavengingS2.connect(other1).exit();

    const balance0 = await orb.balanceOf(other0.address);
    console.log(balance0.toString());
    const balance1 = await orb.balanceOf(other1.address);
    console.log(balance1.toString());
    const balance2 = await orb.balanceOf(govTreasury.address);
    console.log(balance2.toString());

    expect(balance0.add(balance1).add(balance2)).to.be.equal(5400);
  });

  it('over period finish', async () => {
    const dayScavengingS2 = (await deployContract(owner, ScavengingS2Artifact, [
      orb.address,
      lay.address,
      govTreasury.address,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      1,
      stakingBlockNumber * 100000,
      15,
      0,
    ])) as ScavengingS2;

    await districtInfo['setAttribute(uint256,string[],string[])'](
      1,
      ['Country', 'City', 'Tier', 'Level'],
      ['South Korea', 'Seoul', '1', '1'],
    );

    await lay.connect(other0).approve(dayScavengingS2.address, 10000);

    const duration = 100;
    const totalReward = BigNumber.from(duration * 100);

    const currentBlockNumber = await provider.getBlockNumber();
    const periodStart = currentBlockNumber;

    await dayScavengingS2.setRewardsDuration(periodStart, duration);
    await orb.transfer(dayScavengingS2.address, totalReward);
    await dayScavengingS2.notifyRewardAmount(totalReward);

    //dummy
    await district.mint(other0.address);

    await district.mint(other0.address);

    await district
      .connect(other0)
      .setApprovalForAll(districtStaking.address, true);

    await districtStaking.connect(other0).stake(1);

    await dayScavengingS2.connect(other0).stake(1);

    await expect(dayScavengingS2.connect(other0).exit()).to.be.revertedWith('');

    await mine(100);

    await dayScavengingS2.connect(other0).exit();
  });
});
