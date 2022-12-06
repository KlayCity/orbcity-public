import { ethers } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract, stage } from '../utils/blockchain';

import { BigNumber } from 'ethers';
import { District, DistrictStaking } from '../../typechain';
import { getFastGasPrice } from '../utils/gas-utils';

async function main() {
  const contractsInfo = getContracts();
  const [admin] = await hre.ethers.getSigners();

  const districtStaking = (await ethers.getContractAt(
    contractsInfo.DistrictStaking.abi,
    contractsInfo.DistrictStaking.address,
  )) as DistrictStaking;

  const district = (await ethers.getContractAt(
    contractsInfo.District.abi,
    contractsInfo.District.address,
  )) as District;

  // dummy 0
  //await (await district.mint(admin.address, await getFastGasPrice())).wait();

  // district 1
  //await (await district.mint(admin.address, await getFastGasPrice())).wait();

  // console.log(await district.ownerOf(1));
  // stake

  const approvedAll = await district.isApprovedForAll(
    admin.address,
    districtStaking.address,
  );

  if (approvedAll == false) {
    await district.setApprovalForAll(
      districtStaking.address,
      true,
      await getFastGasPrice(),
    );
  }

  await (await districtStaking.stake(1, await getFastGasPrice())).wait();

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
