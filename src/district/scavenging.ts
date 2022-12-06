import { ethers } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract, stage } from '../utils/blockchain';

import { Lay } from '../../typechain/Lay';
import { Orb } from '../../typechain/Orb';
import { BigNumber } from 'ethers';
import { getFastGasPrice } from '../utils/gas-utils';
import { LevelupS2, ScavengingS2 } from '../../typechain';
import { MAX_UINT256 } from '../utils/constants';

async function main() {
  const contractsInfo = getContracts();
  const [admin] = await hre.ethers.getSigners();

  const openScavengingS2 = (await ethers.getContractAt(
    contractsInfo.OpenScavengingS2.abi,
    contractsInfo.OpenScavengingS2.address,
  )) as ScavengingS2;

  const lay = (await ethers.getContractAt(
    contractsInfo.Lay.abi,
    contractsInfo.Lay.address,
  )) as Lay;

  //approve

  await (
    await lay.approve(
      contractsInfo.OpenScavengingS2.address,
      MAX_UINT256,
      await getFastGasPrice(),
    )
  ).wait();

  //levelup
  await (await openScavengingS2.stake(1, await getFastGasPrice())).wait();

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
