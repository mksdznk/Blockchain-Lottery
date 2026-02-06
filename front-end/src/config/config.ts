// config/config.ts
import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { createConfig, http } from 'wagmi'
import { mainnet,sepolia } from 'wagmi/chains'

export const config = createConfig({
  chains: [sepolia, mainnet],
  transports: {
    [sepolia.id]: http("https://eth-sepolia.g.alchemy.com/v2/uuhYlUhc8b-FX4-r1W9vf"),
    [mainnet.id]: http("https://eth-mainnet.g.alchemy.com/v2/uuhYlUhc8b-FX4-r1W9vf"),
  },
  ssr: true,
})