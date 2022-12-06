import { ethers, web3 } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract } from '../utils/blockchain';
import axios from 'axios';

import DistrictInfoArtifact from '../../artifacts/contracts/district/DistrictInfo.sol/DistrictInfo.json';

import { MAX_UINT256 } from '../utils/constants';
import { BigNumber } from 'ethers';
import { DistrictInfo } from '../../typechain';

async function main() {
  const contractsInfo = getContracts();
  const [admin, tester] = await hre.ethers.getSigners();

  /*
  const districtInfo = (await deployContract(
    DistrictInfoArtifact,
    [],
  )) as DistrictInfo;
*/

  const districtInfo = (await ethers.getContractAt(
    contractsInfo.DistrictInfo.abi,
    contractsInfo.DistrictInfo.address,
  )) as DistrictInfo;

  const districts = require(__dirname + `/districtinfo-meta/districts.json`);

  const tokenIds = Object.keys(districts);

  for (let i = 0; i < tokenIds.length; i++) {
    districts[tokenIds[i]]['Level'] = 1;
  }

  let nonce = await ethers.provider.getTransactionCount(admin.address);
  console.log(nonce);

  let count = 5;
  let i = 1231;
  while (i <= 2010) {
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

    try {
      const currentTokenIds = [];
      for (let j = 0; j < count; j++) {
        currentTokenIds.push(i + j);
      }

      const response = await axios.get(
        'https://gasstation-mainnet.matic.network/v2',
      );

      const maxPriorityFeePerGas = ethers.utils.parseUnits(
        response.data.fast.maxPriorityFee.toFixed(2).toString(),
        'gwei',
      );

      const gasPrice = ethers.utils.parseUnits(
        response.data.fast.maxFee.toFixed(2).toString(),
        'gwei',
      );

      //console.log(maxPriorityFeePerGas.toString());
      console.log(gasPrice.toString());

      const receipt = await districtInfo.setBulkAttributes(
        currentTokenIds,
        keys,
        values,
        {
          gasLimit: 10000000,
          //maxPriorityFeePerGas,
          gasPrice,
        },
      );
      console.log(receipt.gasLimit);
      console.log(receipt.gasPrice);
      console.log(receipt.hash);
      await receipt.wait();

      console.log('add ' + i + ' ' + count + ' ' + new Date().toLocaleString());
      i += count;
    } catch (error) {
      if (error instanceof Error) {
        console.error(error.message);
      }

      console.error(error);
      process.exit(0);
    }
  }

  console.log('finish');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error.message);
    console.error(error);
    process.exit(1);
  });
