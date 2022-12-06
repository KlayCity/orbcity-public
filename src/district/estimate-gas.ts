import { ethers, web3 } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract } from '../utils/blockchain';

import DistrictInfoArtifact from '../../artifacts/contracts/district/DistrictInfo.sol/DistrictInfo.json';

import { MAX_UINT256 } from '../utils/constants';
import { BigNumber } from 'ethers';
import { DistrictInfo } from '../../typechain';

async function main() {
  const contractsInfo = getContracts();
  const [admin, tester] = await hre.ethers.getSigners();

  const districtInfo = (await ethers.getContractAt(
    contractsInfo.DistrictInfo.abi,
    contractsInfo.DistrictInfo.address,
  )) as DistrictInfo;

  let nonce = await ethers.provider.getTransactionCount(admin.address);

  console.log(nonce);

  const districts = require(__dirname + `/districtinfo-meta/districts.json`);

  const tokenIds = Object.keys(districts);

  for (let i = 0; i < tokenIds.length; i++) {
    districts[tokenIds[i]]['Level'] = 1;
  }

  let count = 3;
  let i = 1;
  const keys = ['Country', 'Tier', 'Level'];

  const values = [];
  for (let j = 0; j < count; j++) {
    values.push(districts[i + j].Country);
    values.push(districts[i + j].Tier);
    values.push(districts[i + j].Level);
  }

  for (let j = 0; j < values.length; j++) {
    if (typeof values[j] == 'number') {
      values[j] = values[j].toString();
    }
  }

  const currentTokenIds = [];
  for (let j = 0; j < count; j++) {
    currentTokenIds.push(i + j);
  }

  {
    const gas = await districtInfo.estimateGas.setBulkAttributes(
      currentTokenIds,
      keys,
      values,
      {
        gasLimit: 5000000,
        gasPrice: 300 * 1000000000,
      },
    );

    console.log('Gas: ' + gas);
  }

  {
    let gas = BigNumber.from(0);

    const slicedValues = values.slice(0, 3);
    for (let j = 0; j < count; j++) {
      const eachGas = await districtInfo.estimateGas[
        'setAttribute(uint256,string[],string[])'
      ](currentTokenIds[0], keys, slicedValues);
      gas = gas.add(eachGas);
    }

    console.log('Gas: ' + gas);
  }

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
