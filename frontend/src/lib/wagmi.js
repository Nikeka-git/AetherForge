import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { arbitrumSepolia } from 'wagmi/chains'

export const ARBITRUM_SEPOLIA_ID = 421614

export const config = getDefaultConfig({
  appName: 'AetherForge Arena',
  // Get a free project ID at https://cloud.walletconnect.com
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || 'aetherforge_placeholder',
  chains: [arbitrumSepolia],
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

  if (msg.toLowerCase().includes('network'))
    return 'Network error. Check your connection.'

  return error.shortMessage || msg.slice(0, 120) || 'Unknown error.'
}
