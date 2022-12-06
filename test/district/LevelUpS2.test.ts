import { expect } from 'chai';
import { ethers, waffle } from 'hardhat';
import OrbArtifact from '../../artifacts/contracts/tokens/Orb.sol/Orb.json';
import LayArtifact from '../../artifacts/contracts/tokens/Lay.sol/Lay.json';
import DistrictArtifact from '../../artifacts/contracts/nft/District.sol/District.json';
import LevelupS2Artifact from '../../artifacts/contracts/district/LevelupS2.sol/LevelupS2.json';
import DistrictInfoArtifact from '../../artifacts/contracts/district/DistrictInfo.sol/DistrictInfo.json';
import DistrictStakingArtifact from '../../artifacts/contracts/district/DistrictStaking.sol/DistrictStaking.json';
import { Lay } from '../../typechain/Lay';
import { Orb } from '../../typechain/Orb';
import { LevelupS2 } from '../../typechain/LevelupS2';
import { District } from '../../typechain/District';
import { DistrictInfo } from '../../typechain/DistrictInfo';
import { DistrictStaking } from '../../typechain/DistrictStaking';
import { mine } from '../utils/blockchain';
import { BigNumber } from '@ethersproject/bignumber';
import { ContractReceipt } from 'ethers';

const { deployContract } = waffle;

describe('LevelupS2', () => {
  let lay: Lay;
  let orb: Orb;
  let levelupS2: LevelupS2;
  let district: District;
  let districtInfo: DistrictInfo;
  let districtStaking: DistrictStaking;

  const provider = waffle.provider;
  const [admin, other, communityTreasury] = provider.getWallets();

  const layInitSupply = BigNumber.from(10).pow(18).mul(30000);
  const orbInitSupply = BigNumber.from(10).pow(18).mul(1000000000);

  beforeEach(async () => {
    lay = (await deployContract(admin, LayArtifact, ['', ''])) as Lay;
    orb = (await deployContract(admin, OrbArtifact, ['', ''])) as Orb;
    district = (await deployContract(admin, DistrictArtifact, [
      'KlayCity District',
      'District',
      'https:dummy.com/',
    ])) as District;
    districtInfo = (await deployContract(
      admin,
      DistrictInfoArtifact,
      [],
    )) as DistrictInfo;
    districtStaking = (await deployContract(admin, DistrictStakingArtifact, [
      district.address,
      districtInfo.address,
      0,
    ])) as DistrictStaking;

    levelupS2 = (await deployContract(admin, LevelupS2Artifact, [
      districtInfo.address,
      district.address,
      districtStaking.address,
      lay.address,
      orb.address,
    ])) as LevelupS2;

    await levelupS2.setVariable(
      [
        { lay: 10000, orb: 10000 },
        { lay: 20000, orb: 20000 },
        { lay: 30000, orb: 30000 },
        { lay: 40000, orb: 40000 },
        { lay: 50000, orb: 50000 },
      ],
      [
        { lay: 1000, orb: 1000 },
        { lay: 2000, orb: 2000 },
        { lay: 3000, orb: 3000 },
        { lay: 4000, orb: 4000 },
        { lay: 5000, orb: 5000 },
      ],
      [
        { lay: 100, orb: 100 },
        { lay: 200, orb: 200 },
        { lay: 300, orb: 300 },
        { lay: 400, orb: 400 },
        { lay: 500, orb: 500 },
      ],
    );
    await levelupS2.setStartBlockNumber(0);
    await levelupS2.setPriceFormula(communityTreasury.address, 80);

    await districtInfo.addAdmin(levelupS2.address);

    await orb.mint(admin.address, layInitSupply);
    await lay.mint(admin.address, orbInitSupply);
  });

  it('one tier levelup', async () => {
    await districtInfo['setAttribute(uint256,string[],string[])'](
      1,
      ['Country', 'City', 'Tier', 'Level'],
      ['China', 'Beijing', '1', '1'],
    );

    //dummy
    await district.mint(admin.address);
    await district.mint(admin.address);

    const costs = await levelupS2.getCosts();
    expect(costs.oneTier[0].orb).to.be.equal(10000);
    expect(costs.oneTier[0].lay).to.be.equal(10000);

    expect(costs.threeTier[4].orb).to.be.equal(500);
    expect(costs.threeTier[4].lay).to.be.equal(500);

    // approve all
    await lay.approve(levelupS2.address, 10000000);
    await orb.approve(levelupS2.address, 10000000);

    await expect(levelupS2.connect(other).levelUp(1)).to.reverted;

    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 1, 1, 2, 8000, 8000, 2000, 2000);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 1, 2, 3, 16000, 16000, 4000, 4000);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 1, 3, 4, 24000, 24000, 6000, 6000);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 1, 4, 5, 32000, 32000, 8000, 8000);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 1, 5, 6, 40000, 40000, 10000, 10000);

    const level = await districtInfo['getAttribute(uint256,string)'](
      1,
      'Level',
    );
    expect(level).to.be.equal('6');

    await expect(levelupS2.levelUp(1)).to.reverted;
  });

  it('two tier levelup', async () => {
    await districtInfo['setAttribute(uint256,string[],string[])'](
      1,
      ['Country', 'City', 'Tier', 'Level'],
      ['China', 'Beijing', '2', '1'],
    );

    //dummy
    await district.mint(admin.address);
    await district.mint(admin.address);

    // approve all
    await lay.approve(levelupS2.address, 10000000);
    await orb.approve(levelupS2.address, 10000000);

    await expect(levelupS2.connect(other).levelUp(1)).to.reverted;

    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 2, 1, 2, 800, 800, 200, 200);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 2, 2, 3, 1600, 1600, 400, 400);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 2, 3, 4, 2400, 2400, 600, 600);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 2, 4, 5, 3200, 3200, 800, 800);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 2, 5, 6, 4000, 4000, 1000, 1000);

    const level = await districtInfo['getAttribute(uint256,string)'](
      1,
      'Level',
    );
    expect(level).to.be.equal('6');
  });

  it('three tier levelup', async () => {
    await districtInfo['setAttribute(uint256,string[],string[])'](
      1,
      ['Country', 'City', 'Tier', 'Level'],
      ['China', 'Beijing', '3', '1'],
    );

    //dummy
    await district.mint(admin.address);
    await district.mint(admin.address);

    // approve all
    await lay.approve(levelupS2.address, 10000000);
    await orb.approve(levelupS2.address, 10000000);

    await expect(levelupS2.connect(other).levelUp(1)).to.reverted;

    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 3, 1, 2, 80, 80, 20, 20);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 3, 2, 3, 160, 160, 40, 40);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 3, 3, 4, 240, 240, 60, 60);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 3, 4, 5, 320, 320, 80, 80);
    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 3, 5, 6, 400, 400, 100, 100);

    const level = await districtInfo['getAttribute(uint256,string)'](
      1,
      'Level',
    );
    expect(level).to.be.equal('6');

    await expect(levelupS2.levelUp(1)).to.reverted;
  });

  it('staked district levelup', async () => {
    await districtInfo['setAttribute(uint256,string[],string[])'](
      1,
      ['Country', 'City', 'Tier', 'Level'],
      ['China', 'Beijing', '3', '1'],
    );

    //dummy
    await district.mint(admin.address);
    await district.mint(admin.address);

    // approve all
    await lay.approve(levelupS2.address, 10000000);
    await orb.approve(levelupS2.address, 10000000);

    await district.setApprovalForAll(districtStaking.address, true);

    await districtStaking.stake(1);

    await expect(levelupS2.levelUp(1))
      .to.emit(levelupS2, 'LevelUp')
      .withArgs(admin.address, 1, 3, 1, 2, 80, 80, 20, 20);

    const level = await districtInfo['getAttribute(uint256,string)'](
      1,
      'Level',
    );
    expect(level).to.be.equal('2');
  });
});
