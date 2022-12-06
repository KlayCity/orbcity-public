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

  const districtInfo = (await ethers.getContractAt(
    contractsInfo.DistrictInfo.abi,
    contractsInfo.DistrictInfo.address,
  )) as DistrictInfo;

  const districtStaking = (await ethers.getContractAt(
    contractsInfo.DistrictStaking.abi,
    contractsInfo.DistrictStaking.address,
  )) as DistrictStaking;

  const diceGameS2 = (await ethers.getContractAt(
    contractsInfo.DiceGameS2.abi,
    contractsInfo.DiceGameS2.address,
  )) as DiceGameS2;

  const levelupS2 = (await ethers.getContractAt(
    contractsInfo.LevelupS2.abi,
    contractsInfo.LevelupS2.address,
  )) as LevelupS2;

  // setting

  await (await districtStaking.addAdmin(contractsInfo.DiceGameS2.address)).wait();

  const tiers: number[] = [1, 2, 3];

  const rewards: BigNumber[] = [
    BigNumber.from(10).pow(18).mul(1),
    BigNumber.from(10).pow(17).mul(6),
    BigNumber.from(10).pow(17).mul(2),
  ];

  const levels: number[] = [1, 2, 3, 4, 5, 6];

  const multiplies: number[] = [0, 50, 150, 300, 500, 1000];

  await (await diceGameS2.addAdmin(admin.address)).wait();
  await (await diceGameS2.addAdmin(contractsInfo.DiceGameS2.address)).wait();
  await (await diceGameS2.setReward(tiers, rewards, levels, multiplies)).wait();

  await (await levelupS2.setVariable(
    [
      {
        lay: BigNumber.from(10).pow(18).mul(50),
        orb: BigNumber.from(10).pow(18).mul(20000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(150),
        orb: BigNumber.from(10).pow(18).mul(50000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(500),
        orb: BigNumber.from(10).pow(18).mul(100000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(1000),
        orb: BigNumber.from(10).pow(18).mul(250000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(2000),
        orb: BigNumber.from(10).pow(18).mul(500000),
      },
    ],
    [
      {
        lay: BigNumber.from(10).pow(18).mul(30),
        orb: BigNumber.from(10).pow(18).mul(12000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(90),
        orb: BigNumber.from(10).pow(18).mul(30000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(300),
        orb: BigNumber.from(10).pow(18).mul(60000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(600),
        orb: BigNumber.from(10).pow(18).mul(150000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(1200),
        orb: BigNumber.from(10).pow(18).mul(300000),
      },
    ],
    [
      {
        lay: BigNumber.from(10).pow(18).mul(10),
        orb: BigNumber.from(10).pow(18).mul(4000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(30),
        orb: BigNumber.from(10).pow(18).mul(10000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(100),
        orb: BigNumber.from(10).pow(18).mul(20000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(200),
        orb: BigNumber.from(10).pow(18).mul(50000),
      },
      {
        lay: BigNumber.from(10).pow(18).mul(400),
        orb: BigNumber.from(10).pow(18).mul(100000),
      },
    ],
  )).wait();

  await (await levelupS2.setStartBlockNumber(0)).wait();
  await (await levelupS2.setPriceFormula(communityTreasury, 80)).wait();

  await (await districtInfo.addAdmin(contractsInfo.LevelupS2.address)).wait();

  if (stage === 'pd') {
    await (await diceGameS2.setWaitTime(85200)).wait();
  } else {
    await (await diceGameS2.setWaitTime(0)).wait();
  }

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
