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

describe('LP Scavenging', () => {
  let orb: Orb;
  let lay: Lay;
  let lpToken: Orb;
  let district: District;
  let districtInfo: DistrictInfo;
  let districtStaking: DistrictStaking;
  let lpScavengingS2: ScavengingS2;

  const provider = waffle.provider;
  const [owner, govTreasury, other0, other1, other2, burnPool] =
    provider.getWallets();

  const initSupply: BigNumber = BigNumber.from(10).pow(40);

  const stakingBlockNumber = 50;

  beforeEach(async () => {
    // await ethers.provider.send("hardhat_reset", []);

    lpToken = (await deployContract(owner, OrbArtifact, ['', ''])) as Orb;
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

    lpScavengingS2 = (await deployContract(owner, ScavengingS2Artifact, [
      orb.address,
      lpToken.address,
      govTreasury.address,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      2,
      0,
      15,
      0,
    ])) as ScavengingS2;

    await orb.mint(owner.address, 1000000000);
    await lay.mint(owner.address, 1000000000);
    await lpToken.mint(owner.address, initSupply);

    await lpToken.transfer(other0.address, 10000);
    await lpToken.transfer(other1.address, 10000);
    await lpToken.transfer(other2.address, 10000);
  });

  it('do stake twice, prevent withraw, exit', async () => {
    const duration = 100;
    const totalReward = BigNumber.from(duration * 100);

    let currentBlockNumber = await provider.getBlockNumber();
    const periodStart = currentBlockNumber + 10;

    await lpScavengingS2.setRewardsDuration(periodStart, duration);

    await orb.transfer(lpScavengingS2.address, totalReward);
    await lpScavengingS2.notifyRewardAmount(totalReward);

    await lpToken.connect(other0).approve(lpScavengingS2.address, 10000);
    await lpToken.connect(other1).approve(lpScavengingS2.address, 10000);

    currentBlockNumber = await provider.getBlockNumber();
    const remainBlockNumber = periodStart - currentBlockNumber - 1;
    await mine(remainBlockNumber);

    await lpScavengingS2.connect(other0).stake(1);

    await lpScavengingS2.connect(other0).stake(1);

    await expect(lpScavengingS2.connect(other0).withdraw(1)).to.reverted;
    await expect(lpScavengingS2.connect(other0).exit()).to.reverted;

    expect(await lpToken.balanceOf(burnPool.address)).to.be.equal(2);
  });
});
