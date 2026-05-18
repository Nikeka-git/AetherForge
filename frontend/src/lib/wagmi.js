import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { arbitrumSepolia } from 'wagmi/chains'
import { http } from 'wagmi'
import { parseGwei } from 'viem'

export const ARBITRUM_SEPOLIA_ID = 421614

// Arbitrum Sepolia с буфером газа — baseFee иногда скачет,
// поэтому ставим maxFeePerGas с запасом чтобы не словить revert.
const arbitrumSepoliaWithGas = {
  ...arbitrumSepolia,
  fees: {
    // 2x от текущего baseFee или минимум 0.1 Gwei — более чем достаточно для тестнета
    estimateFeesPerGas: async ({ client }) => {
      try {
        const block = await client.getBlock({ blockTag: 'latest' })
        const baseFee = block.baseFeePerGas ?? parseGwei('0.1')
        const maxFeePerGas = baseFee * 2n + parseGwei('0.001')
        return {
          maxFeePerGas,
          maxPriorityFeePerGas: parseGwei('0.001'),
        }
      } catch {
        return {
          maxFeePerGas: parseGwei('0.5'),
          maxPriorityFeePerGas: parseGwei('0.001'),
        }
      }
    },
  },
}

export const config = getDefaultConfig({
  appName: 'AetherForge Arena',
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || 'aetherforge_placeholder',
  chains: [arbitrumSepoliaWithGas],
  transports: {
    [arbitrumSepolia.id]: http(),
  },
  ssr: false,
})

// ─── Error parser ─────────────────────────────────────────────────────────────
export function parseContractError(error) {
  if (!error) return null
  const msg = error.message || ''

  if (msg.toLowerCase().includes('user rejected') || msg.includes('4001'))
    return 'Transaction rejected by user.'

  if (msg.toLowerCase().includes('insufficient funds'))
    return 'Insufficient funds to cover gas fees.'

  if (msg.includes('execution reverted')) {
    const reason = msg.match(/reason: "?([^"\n]+)"?/)
    if (reason) return `Reverted: ${reason[1]}`
    const custom = msg.match(/error ([A-Z]\w+__\w+)/)
    if (custom) return `Contract error: ${custom[1].replace(/__/, ' → ')}`
    return 'Transaction reverted by contract.'
  }

  if (msg.toLowerCase().includes('max fee per gas less than block base fee'))
    return 'Gas fee too low. Retrying with higher gas — please try again.'

  if (msg.toLowerCase().includes('network'))
    return 'Network error. Check your connection.'

  return error.shortMessage || msg.slice(0, 120) || 'Unknown error.'
}