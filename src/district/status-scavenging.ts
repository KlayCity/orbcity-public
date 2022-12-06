import { ethers } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract, stage } from '../utils/blockchain';

import { Lay } from '../../typechain/Lay';
import { Orb } from '../../typechain/Orb';
import { BigNumber } from 'ethers';
import { getFastGasPrice } from '../utils/gas-utils';

async function main() {
  const contractsInfo = getContracts();
  const [admin] = await hre.ethers.getSigners();

  const orb = (await ethers.getContractAt(
    contractsInfo.Orb.abi,
    contractsInfo.Orb.address,
  )) as Orb;

  console.log(await orb.balanceOf(contractsInfo.OpenScavengingS2.address));
  console.log(await orb.balanceOf(contractsInfo.Day3ScavengingS2.address));
  console.log(await orb.balanceOf(contractsInfo.Day7ScavengingS2.address));
  console.log(await orb.balanceOf(contractsInfo.Day14ScavengingS2.address));
  console.log(await orb.balanceOf(contractsInfo.Day30ScavengingS2.address));
  console.log(await orb.balanceOf(contractsInfo.LPScavengingS2.address));

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
