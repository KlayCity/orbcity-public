import { ethers, web3 } from 'hardhat';
import hre from 'hardhat';
import { getContracts, deployContract } from '../utils/blockchain';
import axios from 'axios';

import DistrictInfoArtifact from '../../artifacts/contracts/district/DistrictInfo.sol/DistrictInfo.json';

import { MAX_UINT256 } from '../utils/constants';
import { BigNumber } from 'ethers';
import { DistrictInfo } from '../../typechain';
import { assert, expect } from 'chai';

async function main() {
  const contractsInfo = getContracts();
  const [admin, tester] = await hre.ethers.getSigners();

  const districtInfo = (await ethers.getContractAt(
    contractsInfo.DistrictInfo.abi,
    contractsInfo.DistrictInfo.address,
  )) as DistrictInfo;

  const districts = require(__dirname + `/districtinfo-meta/districts.json`);

  const tokenIds = Object.keys(districts);

  for (let i = 0; i < tokenIds.length; i++) {
    districts[tokenIds[i]]['Level'] = 1;
  }

  try {
    for (let i = 1; i <= 2010; i++) {
      const country = await districtInfo['getAttribute(uint256,string)'](
        i,
        'Country',
      );
      const tier = await districtInfo['getAttribute(uint256,string)'](
        i,
        'Tier',
      );
      const level = await districtInfo['getAttribute(uint256,string)'](
        i,
        'Level',
      );

      expect(districts[i.toString()].Country).to.be.equal(country);
      expect(districts[i.toString()].Tier).to.be.equal(parseInt(tier));
      expect(districts[i.toString()].Level).to.be.equal(parseInt(level));

      console.log('check ' + i);
    }
  } catch (error) {
    if (error instanceof Error) {
      console.error(error.message);
    }

    console.error(error);
    process.exit(0);
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
