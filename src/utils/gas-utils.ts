import axios from 'axios';
import { ethers } from 'hardhat';

export async function getFastGasPrice() {
  const response = await axios.get(
    'https://gasstation-mainnet.matic.network/v2',
  );

  const gasPrice = ethers.utils.parseUnits(
    response.data.fast.maxFee.toFixed(2).toString(),
    'gwei',
  );

  const gasLimit = 10000000;

  return { gasLimit, gasPrice };
}
