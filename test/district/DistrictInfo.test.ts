import { expect } from 'chai';
import { ethers, waffle } from 'hardhat';

import DistrictInfoArtifact from '../../artifacts/contracts/district/DistrictInfo.sol/DistrictInfo.json';

import { DistrictInfo } from '../../typechain/DistrictInfo';

import { mine } from '../utils/blockchain';
import { BigNumber } from '@ethersproject/bignumber';
import { ContractReceipt } from 'ethers';

const { deployContract } = waffle;

describe('DistrictInfo', () => {
  let districtInfo: DistrictInfo;

  const provider = waffle.provider;
  const [owner, admin, other0, other1, other2] = provider.getWallets();

  before(async () => {});

  beforeEach(async () => {
    districtInfo = (await deployContract(
      owner,
      DistrictInfoArtifact,
      [],
    )) as DistrictInfo;
  });

  it('replace country test', async () => {
    await districtInfo['setAttribute(uint256,string,string)'](
      1,
      'Country',
      'Korea',
    );
    await districtInfo['setAttribute(uint256,string,string)'](
      2,
      'Country',
      'Korea',
    );
    await districtInfo['setAttribute(uint256,string,string)'](
      1,
      'Country',
      'Japan',
    );
    await districtInfo['setAttribute(uint256,string,string)'](
      2,
      'Country',
      'Japan',
    );

    const country1 = await districtInfo['getAttribute(uint256,string)'](
      1,
      'Country',
    );
    const country2 = await districtInfo['getAttribute(uint256,string)'](
      2,
      'Country',
    );

    const tokenIds1 = await districtInfo.getTokenIdsByCountry('Korea');
    const tokenIds2 = await districtInfo.getTokenIdsByCountry('Japan');

    expect(tokenIds1.length).to.be.equal(0);
    expect(tokenIds2.length).to.be.equal(2);

    expect(country1).to.be.equal('Japan');
    expect(country2).to.be.equal('Japan');
  });

  it('bulk insert', async () => {
    await districtInfo.setBulkAttributes(
      [1, 2, 3, 4],
      ['key1', 'key2', 'key3'],
      ['1', '2', '3', '1', '2', '3', '1', '2', '3', '1', '2', '3'],
    );
  });
});
