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

  const district = (await deployContract(DistrictArtifact, [
    'DST',
    'DST',
    'https:dummy.com/',
  ])) as District;
  //0x84701dA0CbfC1a54Bb9a4CB0DE775C0d5307261A
  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
