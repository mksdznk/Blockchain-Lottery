// contracts.ts
import { abi } from "../abis/LotteryFunctions.json";
 
export const lotteryFunctionsContractConfig = {
    address: '0xd89Ef0F8Ba60e11a3bb93ceE5079822290a2f69a' as const,
    abi: abi,
  } as const;

export const lotteryFunctionsAddress = '0xd89Ef0F8Ba60e11a3bb93ceE5079822290a2f69a';