import { ethers } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract, stage } from '../utils/blockchain';

import { Lay } from '../../typechain/Lay';
import { Orb } from '../../typechain/Orb';
import { ScavengingS2 } from '../../typechain/ScavengingS2';

import { communityTreasury, govTreasury } from '../utils/constants';
import { BigNumber } from 'ethers';

async function main() {
  const contractsInfo = getContracts();
  const [admin] = await hre.ethers.getSigners();

  const openScavengingS2 = (await ethers.getContractAt(
    contractsInfo.openScavengingS2.abi,
    contractsInfo.openScavengingS2.address,
  )) as ScavengingS2;

  const day3ScavengingS2 = (await ethers.getContractAt(
    contractsInfo.Day3ScavengingS2.abi,
    contractsInfo.Day3ScavengingS2.address,
  )) as ScavengingS2;

  const day7ScavengingS2 = (await ethers.getContractAt(
    contractsInfo.Day7ScavengingS2.abi,
    contractsInfo.Day7ScavengingS2.address,
  )) as ScavengingS2;

  const day14ScavengingS2 = (await ethers.getContractAt(
    contractsInfo.Day14ScavengingS2.abi,
    contractsInfo.Day14ScavengingS2.address,
  )) as ScavengingS2;

  const day30ScavengingS2 = (await ethers.getContractAt(
    contractsInfo.Day30ScavengingS2.abi,
    contractsInfo.Day30ScavengingS2.address,
  )) as ScavengingS2;

  const lpScavengingS2 = (await ethers.getContractAt(
    contractsInfo.LPScavengingS2.abi,
    contractsInfo.LPScavengingS2.address,
  )) as ScavengingS2;

  let startBlockNumber = BigNumber.from(0);

  if (stage === 'pd') {
    // myc0058 : 오픈할때 제대로된 값으로 넣어야 됨
    startBlockNumber = BigNumber.from(35108177);
  } else {
    startBlockNumber = BigNumber.from(35108177);
  }

  let reward = BigNumber.from(10).pow(18).mul(403200);

  await openScavengingS2.setRewardsDuration(
    startBlockNumber,
    60 * 60 * 24 * 120,
  );
  await openScavengingS2.notifyRewardAmount(reward);

  reward = BigNumber.from(10).pow(18).mul(604800);

  await day3ScavengingS2.setRewardsDuration(
    startBlockNumber,
    60 * 60 * 24 * 120,
  );
  await day3ScavengingS2.notifyRewardAmount(reward);

  reward = BigNumber.from(10).pow(18).mul(604800);

  await day7ScavengingS2.setRewardsDuration(
    startBlockNumber,
    60 * 60 * 24 * 120,
  );
  await day7ScavengingS2.notifyRewardAmount(reward);

  reward = BigNumber.from(10).pow(18).mul(1209600);

  await day14ScavengingS2.setRewardsDuration(
    startBlockNumber,
    60 * 60 * 24 * 120,
  );
  await day14ScavengingS2.notifyRewardAmount(reward);

  reward = BigNumber.from(10).pow(18).mul(2822400);

  await day30ScavengingS2.setRewardsDuration(
    startBlockNumber,
    60 * 60 * 24 * 120,
  );
  await day30ScavengingS2.notifyRewardAmount(reward);

  reward = BigNumber.from(10).pow(18).mul(2419200);

  await lpScavengingS2.setRewardsDuration(startBlockNumber, 60 * 60 * 24 * 120);
  await lpScavengingS2.notifyRewardAmount(reward);

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
