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

  const orb = (await ethers.getContractAt(
    contractsInfo.Orb.abi,
    contractsInfo.Orb.address,
  )) as Orb;

  let balance = await orb.balanceOf(admin.address);
  if (BigNumber.from(0).eq(balance) === true) {
    await (
      await orb.mint(
        admin.address,
        BigNumber.from(10).pow(18).mul(1000000000000),
      )
    ).wait();
  }

  balance = await orb.balanceOf(contractsInfo.OpenScavengingS2.address);
  if (BigNumber.from(0).eq(balance) === true) {
    const reward = BigNumber.from(10).pow(18).mul(403200);
    await (
      await orb.transfer(
        contractsInfo.OpenScavengingS2.address,
        reward,
        await getFastGasPrice(),
      )
    ).wait();
  }

  balance = await orb.balanceOf(contractsInfo.Day3ScavengingS2.address);
  if (BigNumber.from(0).eq(balance) === true) {
    const reward = BigNumber.from(10).pow(18).mul(604800);
    await (
      await orb.transfer(
        contractsInfo.Day3ScavengingS2.address,
        reward,
        await getFastGasPrice(),
      )
    ).wait();
  }

  balance = await orb.balanceOf(contractsInfo.Day7ScavengingS2.address);
  if (BigNumber.from(0).eq(balance) === true) {
    const reward = BigNumber.from(10).pow(18).mul(604800);
    await (
      await orb.transfer(
        contractsInfo.Day7ScavengingS2.address,
        reward,
        await getFastGasPrice(),
      )
    ).wait();
  }

  balance = await orb.balanceOf(contractsInfo.Day14ScavengingS2.address);
  if (BigNumber.from(0).eq(balance) === true) {
    const reward = BigNumber.from(10).pow(18).mul(1209600);
    await (
      await orb.transfer(
        contractsInfo.Day14ScavengingS2.address,
        reward,
        await getFastGasPrice(),
      )
    ).wait();
  }

  balance = await orb.balanceOf(contractsInfo.Day30ScavengingS2.address);
  if (BigNumber.from(0).eq(balance) === true) {
    const reward = BigNumber.from(10).pow(18).mul(2822400);
    await (
      await orb.transfer(
        contractsInfo.Day30ScavengingS2.address,
        reward,
        await getFastGasPrice(),
      )
    ).wait();
  }

  balance = await orb.balanceOf(contractsInfo.LPScavengingS2.address);
  if (BigNumber.from(0).eq(balance) === true) {
    const reward = BigNumber.from(10).pow(18).mul(2419200);
    await (
      await orb.transfer(
        contractsInfo.LPScavengingS2.address,
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
