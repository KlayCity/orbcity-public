import { ethers } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract, stage } from '../utils/blockchain';

import { BigNumber } from 'ethers';
import { DiceGameS2 } from '../../typechain';
import { getFastGasPrice } from '../utils/gas-utils';

async function main() {
  const contractsInfo = getContracts();
  const [admin] = await hre.ethers.getSigners();

  const diceGameS2 = (await ethers.getContractAt(
    contractsInfo.DiceGameS2.abi,
    contractsInfo.DiceGameS2.address,
  )) as DiceGameS2;

  await (await diceGameS2.getLays([1], await getFastGasPrice())).wait();

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
