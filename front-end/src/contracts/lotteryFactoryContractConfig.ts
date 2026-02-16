// contracts.ts
import { abi } from "../abis/LotteryFactory.json";
 
export const lotteryFactoryContractConfig = {
    address: '0xB14F44813A853c2a503A56574529ee134B61895A' as const,
    abi: abi,
  } as const;

export const lotteryFactoryAddress = '0xB14F44813A853c2a503A56574529ee134B61895A';