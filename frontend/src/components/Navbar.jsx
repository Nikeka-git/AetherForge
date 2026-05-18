import { ConnectButton } from '@rainbow-me/rainbowkit'
import { useAccount, useReadContract } from 'wagmi'
import { formatEther } from 'viem'
import { ADDRESSES, AETH_ABI } from '../lib/contracts.js'

const NAV_ITEMS = [
  { id: 'dashboard',   label: 'Overview',   icon: '◈' },
  { id: 'heroes',      label: 'Heroes',     icon: '⚔' },
  { id: 'arena',       label: 'Arena',      icon: '🏟' },
  { id: 'forge',       label: 'Forge',      icon: '🔥' },
  { id: 'marketplace', label: 'Market',     icon: '⚖' },
  { id: 'vault',       label: 'Vault',      icon: '🏦' },
  { id: 'governance',  label: 'DAO',        icon: '⚖️' },
]

export default function Navbar({ activePage, onNavigate }) {
  const { address, isConnected } = useAccount()

  const { data: balance } = useReadContract({
    address: ADDRESSES.AethToken,
    abi: AETH_ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: isConnected && !!address },
  })

  return (
    <header style={{
      borderBottom: '1px solid var(--border)',
      background: 'rgba(7,6,14,0.85)',
      backdropFilter: 'blur(12px)',
      position: 'sticky',
      top: 0,
      zIndex: 100,
    }}>
      {/* Top bar */}
      <div style={{
        maxWidth: 1140,
        margin: '0 auto',
        padding: '0 24px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        height: 60,
      }}>
        {/* Logo */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ fontSize: '1.4rem' }}>⚡</span>
          <span style={{
            fontFamily: 'var(--font-display)',
            fontSize: '1rem',
            fontWeight: 700,
            color: 'var(--amber)',
            letterSpacing: '0.08em',
          }}>
            AETHERFORGE
          </span>
          <span style={{
            fontFamily: 'var(--font-display)',
            fontSize: '0.75rem',
            color: 'var(--muted)',
            letterSpacing: '0.12em',
          }}>
            ARENA
          </span>
        </div>

        {/* Right side */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          {isConnected && balance !== undefined && (
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: '0.7rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>
                AETH Balance
              </div>
              <div style={{ fontFamily: 'var(--font-display)', fontSize: '0.9rem', color: 'var(--amber)' }}>
                {parseFloat(formatEther(balance)).toLocaleString('en-US', { maximumFractionDigits: 2 })}
              </div>
            </div>
          )}
          <ConnectButton
            chainStatus="icon"
            showBalance={false}
            accountStatus="avatar"
          />
        </div>
      </div>

      {/* Nav tabs */}
      <div style={{
        maxWidth: 1140,
        margin: '0 auto',
        padding: '0 24px',
        display: 'flex',
        gap: 0,
        borderTop: '1px solid var(--border)',
        overflowX: 'auto',
      }}>
        {NAV_ITEMS.map(item => (
          <button
            key={item.id}
            onClick={() => onNavigate(item.id)}
            style={{
              padding: '10px 16px',
              background: 'transparent',
              border: 'none',
              borderBottom: activePage === item.id ? '2px solid var(--amber)' : '2px solid transparent',
              color: activePage === item.id ? 'var(--amber)' : 'var(--muted)',
              fontFamily: 'var(--font-body)',
              fontSize: '0.83rem',
              fontWeight: 500,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              whiteSpace: 'nowrap',
              transition: 'all 180ms ease',
              marginBottom: -1,
            }}
            onMouseEnter={e => { if (activePage !== item.id) e.currentTarget.style.color = 'var(--text)' }}
            onMouseLeave={e => { if (activePage !== item.id) e.currentTarget.style.color = 'var(--muted)' }}
          >
            <span>{item.icon}</span>
            {item.label}
          </button>
        ))}
      </div>
    </header>
  )
}
