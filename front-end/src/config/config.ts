// config/config.ts
import { createConfig, http } from 'wagmi'
import { mainnet,sepolia } from 'wagmi/chains'

export const config = createConfig({
  chains: [sepolia, mainnet],
  transports: {
    [sepolia.id]: http(process.env.SEPOLIA_RPC_URL),
    [mainnet.id]: http(process.env.SEPOLIA_RPC_URL),
  },
  ssr: true,
})