// contracts.ts
import { abi } from "../abis/LotteryFactory.json";
 
export const lotteryFactoryContractConfig = {
    address: '0xe50ceb603c19b0509c0424bb821041403A843c1C' as const,
    abi: abi,
  } as const;

export const lotteryFactoryAddress = '0xe50ceb603c19b0509c0424bb821041403A843c1C';