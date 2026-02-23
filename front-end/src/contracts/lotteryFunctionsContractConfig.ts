// contracts.ts
import { abi } from "../abis/LotteryFunctions.json";
 
export const lotteryFunctionsContractConfig = {
    address: '0x0b29fA841d0411B13578Ec4639cb09E92186ce13' as const,
    abi: abi,
  } as const;

export const lotteryFunctionsAddress = '0x0b29fA841d0411B13578Ec4639cb09E92186ce13';