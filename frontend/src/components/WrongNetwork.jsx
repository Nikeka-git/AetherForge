import { useSwitchChain } from 'wagmi'
import { arbitrumSepolia } from 'wagmi/chains'

export default function WrongNetwork() {
  const { switchChain, isPending } = useSwitchChain()

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 200,
      background: 'rgba(7,6,14,0.95)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <div style={{
        background: 'var(--surface)',
        border: '1px solid var(--amber)',
        borderRadius: 12,
        padding: '40px 48px',
        textAlign: 'center',
        maxWidth: 400,
      }}>
        <div style={{ fontSize: '3rem', marginBottom: 16 }}>⚠️</div>
        <h2 style={{
          fontFamily: 'var(--font-display)',
          color: 'var(--amber)',
          marginBottom: 12,
          fontSize: '1.2rem',
        }}>Wrong Network</h2>
        <p style={{ color: 'var(--muted)', marginBottom: 28, fontSize: '0.9rem', lineHeight: 1.6 }}>
          AetherForge Arena runs on <strong style={{ color: 'var(--text)' }}>Arbitrum Sepolia</strong>.
          Please switch your wallet to continue.
        </p>
        <button
          onClick={() => switchChain({ chainId: arbitrumSepolia.id })}
          disabled={isPending}
          style={{
            background: 'var(--amber)',
            color: '#000',
            border: 'none',
            borderRadius: 8,
            padding: '12px 28px',
            fontFamily: 'var(--font-display)',
            fontWeight: 700,
            fontSize: '0.9rem',
            cursor: isPending ? 'wait' : 'pointer',
            letterSpacing: '0.05em',
          }}
        >
          {isPending ? 'Switching…' : 'Switch to Arbitrum Sepolia'}
        </button>
      </div>
    </div>
  )
}
