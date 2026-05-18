import { useState } from 'react'
import { useAccount, useChainId } from 'wagmi'
import { ARBITRUM_SEPOLIA_ID } from './lib/wagmi.js'
import Navbar from './components/Navbar.jsx'
import WrongNetwork from './components/WrongNetwork.jsx'
import Dashboard from './pages/Dashboard.jsx'
import Heroes from './pages/Heroes.jsx'
import Arena from './pages/Arena.jsx'
import Forge from './pages/Forge.jsx'
import Marketplace from './pages/Marketplace.jsx'
import Vault from './pages/Vault.jsx'
import Governance from './pages/Governance.jsx'

const PAGES = {
  dashboard:   Dashboard,
  heroes:      Heroes,
  arena:       Arena,
  forge:       Forge,
  marketplace: Marketplace,
  vault:       Vault,
  governance:  Governance,
}

export default function App() {
  const [page, setPage] = useState('dashboard')
  const { isConnected } = useAccount()
  const chainId = useChainId()

  const wrongNetwork = isConnected && chainId !== ARBITRUM_SEPOLIA_ID

  const Page = PAGES[page] ?? Dashboard

  return (
    <div style={{ minHeight: '100vh', background: 'var(--bg)' }}>
      {wrongNetwork && <WrongNetwork />}
      <Navbar activePage={page} onNavigate={setPage} />
      <main>
        <Page />
      </main>
    </div>
  )
}
