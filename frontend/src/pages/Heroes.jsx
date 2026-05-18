import { useAccount, useReadContract } from 'wagmi'
import { ADDRESSES, HERO_ABI, HERO_CLASSES, HERO_CLASS_ICONS } from '../lib/contracts.js'

export default function Heroes() {
  const { address, isConnected } = useAccount()

  const { data: heroCount } = useReadContract({
    address: ADDRESSES.HeroNFT,
    abi: HERO_ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: isConnected && !!address },
  })

  return (
    <div style={{ maxWidth: 1140, margin: '0 auto', padding: '32px 24px' }}>
      <h1 style={{ fontFamily: 'var(--font-display)', color: 'var(--amber)', marginBottom: 8, fontSize: '1.4rem' }}>
        ⚔ My Heroes
      </h1>
      <p style={{ color: 'var(--muted)', marginBottom: 32, fontSize: '0.88rem' }}>
        Your NFT heroes — each one unique, upgradeable, and battle-ready.
      </p>

      {!isConnected ? (
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: 40, textAlign: 'center', color: 'var(--muted)' }}>
          Connect your wallet to view your heroes
        </div>
      ) : (
        <>
          <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '20px 24px', marginBottom: 24, display: 'inline-block' }}>
            <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 4 }}>Heroes Owned</div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: '2rem', color: 'var(--amber)' }}>
              {heroCount !== undefined ? heroCount.toString() : '—'}
            </div>
          </div>

          <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: 28 }}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '0.9rem', color: 'var(--muted)', marginBottom: 20, textTransform: 'uppercase', letterSpacing: '0.1em' }}>
              Hero Classes
            </h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 }}>
              {HERO_CLASSES.map((cls, i) => (
                <div key={cls} style={{
                  border: '1px solid var(--border)', borderRadius: 8,
                  padding: '20px 16px', textAlign: 'center',
                  background: 'rgba(255,255,255,0.02)',
                }}>
                  <div style={{ fontSize: '2rem', marginBottom: 8 }}>{HERO_CLASS_ICONS[i]}</div>
                  <div style={{ fontFamily: 'var(--font-display)', fontSize: '0.85rem', color: 'var(--text)' }}>{cls}</div>
                </div>
              ))}
            </div>
            <p style={{ color: 'var(--muted)', fontSize: '0.82rem', marginTop: 20 }}>
              Individual hero stats and token IDs are available via the contract.
              Minting is restricted to authorized minters — contact the DAO to request access.
            </p>
          </div>
        </>
      )}
    </div>
  )
}
