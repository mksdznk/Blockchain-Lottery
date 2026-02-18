// contracts.ts
import { abi } from "../abis/LotteryFunctions.json";
 
export const lotteryFunctionsContractConfig = {
    address: '0x6C797BB99e8A76c557379e0A310C353Ca81ad157' as const,
    abi: abi,
  } as const;

export const lotteryFunctionsAddress = '0x6C797BB99e8A76c557379e0A310C353Ca81ad157';