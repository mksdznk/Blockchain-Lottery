// contracts.ts
import { abi } from "../abis/LotteryFunctions.json";
 
export const lotteryFunctionsContractConfig = {
    address: '0x820F2D5CA84648B389e72e1dfcb2B685D34d609E' as const,
    abi: abi,
  } as const;

export const lotteryFunctionsAddress = '0x820F2D5CA84648B389e72e1dfcb2B685D34d609E';