import { ethers } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract, stage } from '../utils/blockchain';

import { Lay } from '../../typechain/Lay';
import { Orb } from '../../typechain/Orb';
import { BigNumber } from 'ethers';
import { getFastGasPrice } from '../utils/gas-utils';
import { LevelupS2 } from '../../typechain';
import { MAX_UINT256 } from '../utils/constants';

async function main() {
  const contractsInfo = getContracts();
  const [admin] = await hre.ethers.getSigners();

  const levelupS2 = (await ethers.getContractAt(
    contractsInfo.LevelupS2.abi,
    contractsInfo.LevelupS2.address,
  )) as LevelupS2;

  const lay = (await ethers.getContractAt(
    contractsInfo.Lay.abi,
    contractsInfo.Lay.address,
  )) as Lay;

  const orb = (await ethers.getContractAt(
    contractsInfo.Orb.abi,
    contractsInfo.Orb.address,
  )) as Orb;

  //approve

  await (
    await orb.approve(
      contractsInfo.LevelupS2.address,
      MAX_UINT256,
      await getFastGasPrice(),
    )
  ).wait();

  await (
    await lay.approve(
      contractsInfo.LevelupS2.address,
      MAX_UINT256,
      await getFastGasPrice(),
    )
  ).wait();

  //levelup
  await (await levelupS2.levelUp(1, await getFastGasPrice())).wait();

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
