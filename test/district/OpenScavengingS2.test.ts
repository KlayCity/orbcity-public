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

describe('Open Scavenging', () => {
  let orb: Orb;
  let lay: Lay;
  let district: District;
  let districtInfo: DistrictInfo;
  let districtStaking: DistrictStaking;
  let openScavengingS2: ScavengingS2;

  const provider = waffle.provider;
  const [owner, admin, govTreasury, other0, other1, other2, burnPool] =
    provider.getWallets();

  const initSupply: BigNumber = BigNumber.from(10).pow(40);

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

    openScavengingS2 = (await deployContract(owner, ScavengingS2Artifact, [
      orb.address,
      lay.address,
      govTreasury.address,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      0,
      0,
      15,
      0,
    ])) as ScavengingS2;

    await orb.mint(owner.address, BigNumber.from(10).pow(18).mul(315000));

    await lay.mint(owner.address, BigNumber.from(10).pow(18).mul(315000));
    await lay.transfer(other0.address, 10000);
    await lay.transfer(other1.address, 10000);
    await lay.transfer(other2.address, 10000);
  });

  it('stake twice', async () => {
    const duration = 100;
    const totalReward = BigNumber.from(duration * 100);

    let currentBlockNumber = await provider.getBlockNumber();
    const periodStart = currentBlockNumber + 10;

    await openScavengingS2.setRewardsDuration(periodStart, duration);

    await orb.transfer(openScavengingS2.address, totalReward);
    await openScavengingS2.notifyRewardAmount(totalReward);

    const rewardForDuration = await openScavengingS2.getRewardForDuration();

    await lay.connect(other0).approve(openScavengingS2.address, 10000);
    await lay.connect(other1).approve(openScavengingS2.address, 10000);

    currentBlockNumber = await provider.getBlockNumber();
    const remainBlockNumber = periodStart - currentBlockNumber - 1;
    await mine(remainBlockNumber);

    await mine(2);
    await openScavengingS2.connect(other0).stake(1);
    await mine(2);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(200);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(0);

    await openScavengingS2.connect(other1).stake(1);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(300);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(0);

    await mine(2);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(400);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(100);

    await openScavengingS2.connect(other0).stake(1);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(450);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(150);

    await mine(2);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(582);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(216);

    await openScavengingS2.connect(other0).withdraw(1);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(650);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(250);

    await openScavengingS2.connect(other0).withdraw(1);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(700);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(300);

    await mine(2);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(700);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(500);

    await openScavengingS2.connect(other1).withdraw(1);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(700);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(600);

    await mine(2);

    expect(await openScavengingS2.earned(other0.address)).to.be.equal(700);
    expect(await openScavengingS2.earned(other1.address)).to.be.equal(600);

    await openScavengingS2.connect(other0).getReward();
    await openScavengingS2.connect(other1).getReward();

    expect(await orb.balanceOf(other0.address)).to.be.equal(595); // org 700
    expect(await orb.balanceOf(other1.address)).to.be.equal(510); // org 600

    const balance = await orb.balanceOf(govTreasury.address);
    expect(balance).to.be.equal(195);

    await districtInfo['setAttribute(uint256,string[],string[])'](
      1,
      ['Country', 'City', 'Tier', 'Level'],
      ['South Korea', 'Seoul', '1', '1'],
    );

    await districtInfo['setAttribute(uint256,string[],string[])'](
      2,
      ['Country', 'City', 'Tier', 'Level'],
      ['South Korea', 'Seoul', '2', '2'],
    );

    // dummy
    await district.mint(other0.address);

    await district.mint(other0.address);
    await district.mint(other1.address);

    await district
      .connect(other0)
      .setApprovalForAll(districtStaking.address, true);
    await districtStaking.connect(other0).stake(1);

    expect(await orb.balanceOf(openScavengingS2.address)).to.be.equal(
      totalReward.sub(1300),
    );
  });

  it('puase test', async () => {
    await openScavengingS2.pause();

    await expect(openScavengingS2.connect(other0).stake(1)).to.reverted;
  });

  it('Set reward large amount', async () => {
    await openScavengingS2.setRewardsDuration(82659192, 60 * 60 * 24 * 120);

    const reward = BigNumber.from(10).pow(18).mul(315000);
    await orb.transfer(openScavengingS2.address, reward);
    await openScavengingS2.notifyRewardAmount(reward);
  });
});
