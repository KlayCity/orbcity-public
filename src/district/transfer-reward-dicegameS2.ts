import { ethers } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract, stage } from '../utils/blockchain';

import { Lay } from '../../typechain/Lay';
import { Orb } from '../../typechain/Orb';
import { ScavengingS2 } from '../../typechain/ScavengingS2';

import { communityTreasury, govTreasury } from '../utils/constants';
import { BigNumber } from 'ethers';
import { getFastGasPrice } from '../utils/gas-utils';

async function main() {
  const contractsInfo = getContracts();
  const [admin] = await hre.ethers.getSigners();

  const lay = (await ethers.getContractAt(
    contractsInfo.Lay.abi,
    contractsInfo.Lay.address,
  )) as Lay;

  let balance = await lay.balanceOf(admin.address);
  if (BigNumber.from(0).eq(balance) === true) {
    await (
      await lay.mint(
        admin.address,
        BigNumber.from(10).pow(18).mul(1000000000000),
      )
    ).wait();
  }

  balance = await lay.balanceOf(contractsInfo.DiceGameS2.address);
  if (BigNumber.from(0).eq(balance) === true) {
    const reward = BigNumber.from(10).pow(18).mul(100000);
    await (
      await lay.transfer(
        contractsInfo.DiceGameS2.address,
        reward,
        await getFastGasPrice(),
      )
    ).wait();
  }

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
