import { expect } from 'chai';
import { ethers, waffle } from 'hardhat';

import DistrictArtifact from '../../artifacts/contracts/nft/District.sol/District.json';

import { District } from '../../typechain/District';

import { mine } from '../utils/blockchain';
import { BigNumber } from '@ethersproject/bignumber';
import { ContractReceipt } from 'ethers';

const { deployContract } = waffle;

describe('District', () => {
  let district: District;

  const provider = waffle.provider;
  const [owner, admin, other0, other1, other2, opensea] = provider.getWallets();

  before(async () => {});

  beforeEach(async () => {
    district = (await deployContract(owner, DistrictArtifact, [
      'DST',
      'DST',
      'https:dummy.com/',
    ])) as District;

    await district.connect(owner).mint(owner.address);
    await district.connect(owner).mint(owner.address);
    await district.connect(owner).mint(owner.address);

    await district.connect(owner).mint(admin.address);
    await district.connect(owner).mint(admin.address);
    await district.connect(owner).mint(admin.address);
  });

  it('minter role test', async () => {
    await expect(district.connect(admin).setBaseURI('ttt')).to.revertedWith(
      'setBaseURI: must have minter role',
    );

    await expect(district.connect(admin).mint(admin.address)).to.revertedWith(
      'mint: must have minter role to mint',
    );
  });

  it('freeze role test', async () => {
    expect(await district.balanceOf(owner.address)).to.be.equal(4);

    await expect(
      district.transferFrom(owner.address, admin.address, 0),
    ).to.revertedWith('frozen token');

    await district.connect(owner).transferFrom(owner.address, admin.address, 1);
    expect(await district.balanceOf(owner.address)).to.be.equal(3);

    await district.freezeAccount(owner.address, true);

    await expect(
      district.connect(owner).transferFrom(owner.address, admin.address, 2),
    ).to.revertedWith('frozen account');
    expect(await district.balanceOf(owner.address)).to.be.equal(3);
  });

  it('pause role test', async () => {
    await district.pause();

    await expect(
      district.connect(admin).transferFrom(admin.address, other0.address, 4),
    ).to.revertedWith('ERC721Pausable: token transfer while paused');
  });

  it('transfer role test', async () => {
    await district.connect(admin).approve(opensea.address, 4);
    await district.connect(admin).approve(opensea.address, 5);
    await district.connect(admin).approve(opensea.address, 6);

    await district
      .connect(opensea)
      .transferFrom(admin.address, other0.address, 4);
    await district.setActivateTransferRole(true);

    await expect(
      district.connect(opensea).transferFrom(admin.address, other0.address, 4),
    ).to.revertedWith('transfer: owner or need transfer role');

    var role = await district.TRANSFER_ROLE();
    await district.grantRole(role, opensea.address);

    await district
      .connect(opensea)
      .transferFrom(admin.address, other0.address, 5);

    await district.revokeRole(role, opensea.address);
    await expect(
      district.connect(opensea).transferFrom(admin.address, other0.address, 6),
    ).to.revertedWith('transfer: owner or need transfer role');
  });
});
