// contracts.ts
import { abi } from "../abis/LotteryFunctions.json";
 
export const lotteryFunctionsContractConfig = {
    address: '0x5e9a59C8fd792B47F7919f74902ccc9c3849Fd57' as const,
    abi: abi,
  } as const;

export const lotteryFunctionsAddress = '0x5e9a59C8fd792B47F7919f74902ccc9c3849Fd57';