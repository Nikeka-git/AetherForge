import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { ADDRESSES, HERO_ABI, HERO_CLASSES, HERO_CLASS_ICONS } from '../lib/contracts.js'

const cardStyle = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 10,
  padding: 28,
  marginBottom: 24,
}

const labelStyle = {
  fontSize: '0.72rem',
  color: 'var(--muted)',
  textTransform: 'uppercase',
  letterSpacing: '0.1em',
  marginBottom: 4,
}

const inputStyle = {
  width: '100%',
  background: 'rgba(255,255,255,0.04)',
  border: '1px solid var(--border)',
  borderRadius: 6,
  padding: '10px 14px',
  color: 'var(--text)',
  fontSize: '0.9rem',
  boxSizing: 'border-box',
}

const btnStyle = (disabled) => ({
  width: '100%',
  padding: '12px 0',
  borderRadius: 6,
  border: 'none',
  cursor: disabled ? 'not-allowed' : 'pointer',
  fontFamily: 'var(--font-display)',
  fontSize: '0.85rem',
  letterSpacing: '0.08em',
  background: disabled ? '#3a2f10' : 'linear-gradient(90deg,#c47f17,#e5a020)',
  color: disabled ? '#7a6030' : '#0d0d14',
  transition: 'opacity 0.15s',
  marginTop: 16,
})

export default function Heroes() {
  const { address, isConnected } = useAccount()
  const [recipient, setRecipient] = useState('')
  const [selectedClass, setSelectedClass] = useState(0)
  const [mintStatus, setMintStatus] = useState(null) // null | 'pending' | 'success' | 'error'
  const [mintError, setMintError] = useState('')

  // ── Read: how many heroes does the connected wallet own ──────────────────
  const { data: heroCount, refetch: refetchCount } = useReadContract({
    address: ADDRESSES.HeroNFT,
    abi: HERO_ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: isConnected && !!address },
  })


  // ── Write: mintHero ──────────────────────────────────────────────────────
  const { writeContractAsync } = useWriteContract()
  const [txHash, setTxHash] = useState(null)

  const { isLoading: isTxPending, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
    query: { enabled: !!txHash },
  })

  useEffect(() => {
    if (isTxSuccess) {
      setMintStatus('success')
      setTxHash(null)
      refetchCount()
    }
  }, [isTxSuccess])

  const handleMint = async () => {
    const to = recipient.trim() || address
    if (!to) return
    setMintStatus('pending')
    setMintError('')
    try {
      const hash = await writeContractAsync({
        address: ADDRESSES.HeroNFT,
        abi: HERO_ABI,
        functionName: 'mintHero',
        args: [to, selectedClass],
      })
      setTxHash(hash)
    } catch (err) {
      setMintStatus('error')
      const msg = err?.shortMessage || err?.message || 'Transaction failed'
      setMintError(msg)
    }
  }

  const isBusy = mintStatus === 'pending' || isTxPending

  // ── Render ───────────────────────────────────────────────────────────────
  return (
    <div style={{ maxWidth: 1140, margin: '0 auto', padding: '32px 24px' }}>
      <h1 style={{ fontFamily: 'var(--font-display)', color: 'var(--amber)', marginBottom: 8, fontSize: '1.4rem' }}>
        ⚔ My Heroes
      </h1>
      <p style={{ color: 'var(--muted)', marginBottom: 32, fontSize: '0.88rem' }}>
        Your NFT heroes — each one unique, upgradeable, and battle-ready.
      </p>

      {!isConnected ? (
        <div style={{ ...cardStyle, textAlign: 'center', color: 'var(--muted)' }}>
          Connect your wallet to view your heroes
        </div>
      ) : (
        <>
          {/* ── Hero count ── */}
          <div style={{ ...cardStyle, display: 'inline-block', marginRight: 16 }}>
            <div style={labelStyle}>Heroes Owned</div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: '2rem', color: 'var(--amber)' }}>
              {heroCount !== undefined ? heroCount.toString() : '—'}
            </div>
          </div>

          {/* ── Hero classes ── */}
          <div style={cardStyle}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '0.9rem', color: 'var(--muted)', marginBottom: 20, textTransform: 'uppercase', letterSpacing: '0.1em' }}>
              Hero Classes
            </h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 }}>
              {HERO_CLASSES.map((cls, i) => (
                <div key={cls} style={{
                  border: `1px solid ${selectedClass === i ? 'var(--amber)' : 'var(--border)'}`,
                  borderRadius: 8,
                  padding: '20px 16px',
                  textAlign: 'center',
                  background: selectedClass === i ? 'rgba(196,127,23,0.08)' : 'rgba(255,255,255,0.02)',
                  cursor: 'pointer',
                  transition: 'border-color 0.15s, background 0.15s',
                }}
                  onClick={() => setSelectedClass(i)}
                >
                  <div style={{ fontSize: '2rem', marginBottom: 8 }}>{HERO_CLASS_ICONS[i]}</div>
                  <div style={{ fontFamily: 'var(--font-display)', fontSize: '0.85rem', color: 'var(--text)' }}>{cls}</div>
                </div>
              ))}
            </div>
          </div>

          {/* ── Mint section ── */}
          <div style={cardStyle}>
              <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '0.9rem', color: 'var(--amber)', marginBottom: 4, textTransform: 'uppercase', letterSpacing: '0.1em' }}>
                🔨 Mint Hero
              </h2>
              <p style={{ color: 'var(--muted)', fontSize: '0.82rem', marginBottom: 20 }}>
                Anyone can mint a hero — no role required. You'll receive <span style={{ color: 'var(--amber)' }}>100 AETH</span> starter pack automatically.
              </p>

              <div style={{ marginBottom: 16 }}>
                <div style={labelStyle}>Selected Class</div>
                <div style={{ color: 'var(--amber)', fontFamily: 'var(--font-display)', fontSize: '1.1rem' }}>
                  {HERO_CLASS_ICONS[selectedClass]} {HERO_CLASSES[selectedClass]} (class id: {selectedClass})
                </div>
              </div>

              <div style={{ marginBottom: 4 }}>
                <div style={labelStyle}>Recipient Address (leave blank to mint to yourself)</div>
                <input
                  style={inputStyle}
                  placeholder={address}
                  value={recipient}
                  onChange={e => setRecipient(e.target.value)}
                />
              </div>

              <button
                style={btnStyle(isBusy)}
                disabled={isBusy}
                onClick={handleMint}
              >
                {isBusy ? 'Minting…' : `Mint ${HERO_CLASSES[selectedClass]}`}
              </button>

              {mintStatus === 'success' && (
                <div style={{ marginTop: 12, padding: '10px 14px', borderRadius: 6, background: 'rgba(34,197,94,0.1)', border: '1px solid rgba(34,197,94,0.3)', color: '#4ade80', fontSize: '0.85rem' }}>
                  ✅ Hero minted successfully!
                </div>
              )}
              {mintStatus === 'error' && (
                <div style={{ marginTop: 12, padding: '10px 14px', borderRadius: 6, background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)', color: '#f87171', fontSize: '0.85rem' }}>
                  ❌ {mintError}
                </div>
              )}
            </div>
        </>
      )}
    </div>
  )
}
