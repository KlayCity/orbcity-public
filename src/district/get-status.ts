import { ethers } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract, stage } from '../utils/blockchain';

import OrbArtifact from '../../artifacts/contracts/tokens/Orb.sol/Orb.json';
import LayArtifact from '../../artifacts/contracts/tokens/Lay.sol/Lay.json';
import DistrictArtifact from '../../artifacts/contracts/nft/District.sol/District.json';
import DistrictStakingArtifact from '../../artifacts/contracts/district/DistrictStaking.sol/DistrictStaking.json';
import DistrictInfoArtifact from '../../artifacts/contracts/district/DistrictInfo.sol/DistrictInfo.json';

import DiceGameS2Artifact from '../../artifacts/contracts/district/DiceGameS2.sol/DiceGameS2.json';
import LevelupS2Artifact from '../../artifacts/contracts/district/LevelupS2.sol/LevelupS2.json';
import ScavengingS2Artifact from '../../artifacts/contracts/district/ScavengingS2.sol/ScavengingS2.json';

import BurnPoolArtifact from '../../artifacts/contracts/burn/BurnPool.sol/BurnPool.json';

import { Lay } from '../../typechain/Lay';
import { Orb } from '../../typechain/Orb';
import { District } from '../../typechain/District';

import { DistrictInfo } from '../../typechain/DistrictInfo';
import { DistrictStaking } from '../../typechain/DistrictStaking';

import { DiceGameS2 } from '../../typechain/DiceGameS2';
import { LevelupS2 } from '../../typechain/LevelupS2';
import { ScavengingS2 } from '../../typechain/ScavengingS2';

import {
  communityTreasury,
  govTreasury,
  MAX_UINT256,
} from '../utils/constants';
import { BigNumber } from 'ethers';

async function main() {
  const contractsInfo = getContracts();
  const [admin] = await hre.ethers.getSigners();

  const lay = (await deployContract(LayArtifact, ['LT', 'LT'])) as Lay;
  const orb = (await deployContract(OrbArtifact, ['OT', 'OT'])) as Orb;
  const district = (await deployContract(DistrictArtifact, [
    'DST',
    'DST',
    'https:dummy.com/',
  ])) as District;

  const districtInfo = (await deployContract(
    DistrictInfoArtifact,
    [],
  )) as DistrictInfo;

  const districtStaking = (await deployContract(DistrictStakingArtifact, [
    district.address,
    districtInfo.address,
    0,
  ])) as DistrictStaking;

  const diceGameS2 = (await deployContract(DiceGameS2Artifact, [
    lay.address,
    district.address,
    districtInfo.address,
    govTreasury,
    districtStaking.address,
  ])) as DiceGameS2;

  const levelupS2 = (await deployContract(LevelupS2Artifact, [
    districtInfo.address,
    district.address,
    districtStaking.address,
    lay.address,
    orb.address,
  ])) as LevelupS2;

  const burnPool = (await deployContract(BurnPoolArtifact, [])) as LevelupS2;

  const openScavengingS2 = (await deployContract(
    ScavengingS2Artifact,
    [
      orb.address,
      lay.address,
      govTreasury,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      0,
      0,
      15,
      0,
    ],
    'OpenScavengingS2',
  )) as ScavengingS2;

  const day3ScavengingS2 = (await deployContract(
    ScavengingS2Artifact,
    [
      orb.address,
      lay.address,
      govTreasury,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      1,
      86400 * 3,
      15,
      4,
    ],
    'Day3ScavengingS2',
  )) as ScavengingS2;

  const day7ScavengingS2 = (await deployContract(
    ScavengingS2Artifact,
    [
      orb.address,
      lay.address,
      govTreasury,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      1,
      86400 * 7,
      15,
      3,
    ],
    'Day7ScavengingS2',
  )) as ScavengingS2;

  const day14ScavengingS2 = (await deployContract(
    ScavengingS2Artifact,
    [
      orb.address,
      lay.address,
      govTreasury,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      1,
      86400 * 14,
      15,
      2,
    ],
    'Day14ScavengingS2',
  )) as ScavengingS2;

  const day30ScavengingS2 = (await deployContract(
    ScavengingS2Artifact,
    [
      orb.address,
      lay.address,
      govTreasury,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      1,
      86400 * 30,
      15,
      0,
    ],
    'Day30ScavengingS2',
  )) as ScavengingS2;

  const lpScavengingS2 = (await deployContract(
    ScavengingS2Artifact,
    [
      orb.address,
      lay.address, // myc0058 : 임시
      govTreasury,
      districtStaking.address,
      districtInfo.address,
      burnPool.address,
      2,
      0,
      15,
      0,
    ],
    'LPScavengingS2',
  )) as ScavengingS2;

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
