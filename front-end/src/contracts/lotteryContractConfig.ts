// contracts.ts
import { abi } from "../abis/Lottery.json";
 
export const lotteryContractConfig = {
    address: '' as const, // testToken contract address
    abi: abi,
  } as const;