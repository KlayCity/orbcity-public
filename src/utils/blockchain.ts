import { ethers } from 'hardhat';
import hre from 'hardhat';
import * as fs from 'fs';
import { Contract } from '@ethersproject/contracts';
import reader from 'readline-sync';
import 'dotenv/config';

export const stage = process.env.STAGE;
export const name = process.env.NAME;

console.log(`This stage is ${stage}`);
console.log(`The name is ${name}`);

if (stage !== 'qa' && stage !== 'pd') {
  console.log(`Invalid stage ${stage}`);
  process.exit(1);
}

if (name === undefined) {
  console.log(`Invalid name ${name}`);
  process.exit(1);
}

console.log(`chainId :  ${hre.network.config.chainId}`);

if (stage === 'pd') {
  const answer = reader.question(
    'This stage is production. are you sure? [y/n] ',
  );

  switch (answer.toLowerCase()) {
    case 'y':
      break;
    default:
      process.exit(1);
  }
}

export function getContracts(): any {
  try {
    const jsonText = fs.readFileSync(
      __dirname + `/../../deployed/${stage}/ContractsInfo.${name}.json`,
      'utf8',
    );

    return JSON.parse(jsonText);
  } catch {
    return {};
  }
}

function sleep(ms: any) {
  return new Promise((r) => setTimeout(r, ms));
}

function writeContracts(contractsInfo: any): string {
  const dir = __dirname + `/../../deployed/${stage}/`;

  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const filename = dir + `ContractsInfo.${name}.json`;
  fs.writeFileSync(filename, JSON.stringify(contractsInfo, null, 2), {
    flag: 'w',
  });

  return filename;
}

export async function deployContract(
  artifact: any,
  parameters: any[],
  alias = '',
  writeFile = true,
  verify = false,
): Promise<Contract> {
  const factory = await ethers.getContractFactory(artifact.contractName);
  const contract = await factory.deploy(...parameters);
  const receipt = await contract.deployTransaction.wait();

  if (writeFile === false) {
    return contract;
  }

  let contractsInfo = getContracts();

  if (contractsInfo === undefined) {
    contractsInfo = {};
  }

  if (alias === '') {
    alias = artifact.contractName;
  }

  contractsInfo[alias] = {
    chainId: hre.network.config.chainId?.toString(),
    address: contract.address,
    blockNumber: receipt.blockNumber,
    abi: artifact.abi,
  };

  const filename = writeContracts(contractsInfo);

  console.log(
    `The deployed contract '${alias}' address * ${hre.network.config.chainId} ${contract.address} * is recorded on ${filename} file`,
  );

  if (verify === true) {
    console.log('wait 20sec for contract verify.');
    console.log(
      'wait for five confirmations of your contract deployment transaction before running the verification subtask',
    );
    await sleep(20000);

    try {
      await hre.run('verify:verify', {
        address: contract.address,
        constructorArguments: parameters,
      });
    } catch (e) {
      console.log('contract verify throw exception');
      console.log(e);
    }
  }

  return contract;
}
