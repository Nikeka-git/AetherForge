import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { formatEther } from 'viem'
import { ADDRESSES, ARENA_ABI } from '../lib/contracts.js'
import { parseContractError } from '../lib/wagmi.js'
import { fetchActiveBattles } from '../lib/subgraph.js'
import { useEffect } from 'react'

export default function Arena() {
  const { address, isConnected } = useAccount()
  const [heroId, setHeroId] = useState('')
  const [txError, setTxError] = useState(null)
  const [battles, setBattles] = useState([])

  const { data: entryFee } = useReadContract({
    address: ADDRESSES.PvPArena,
    abi: ARENA_ABI,
    functionName: 'entryFee',
  })

  const { data: pendingReward } = useReadContract({
    address: ADDRESSES.PvPArena,
    abi: ARENA_ABI,
    functionName: 'pendingRewards',
    args: [address],
    query: { enabled: isConnected && !!address },
  })

  const { writeContract, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  useEffect(() => {
    fetchActiveBattles().then(setBattles).catch(() => {})
  }, [])

  function handleRegister() {
    setTxError(null)
    try {
      writeContract({
        address: ADDRESSES.PvPArena,
        abi: ARENA_ABI,
        functionName: 'register',
        args: [BigInt(heroId)],
      })
    } catch (e) {
      setTxError(parseContractError(e))
    }
  }

  function handleClaim(battleId) {
    writeContract({
      address: ADDRESSES.PvPArena,
      abi: ARENA_ABI,
      functionName: 'claimReward',
      args: [BigInt(battleId)],
    })
  }

  const fmt = v => v !== undefined ? parseFloat(formatEther(v)).toLocaleString('en-US', { maximumFractionDigits: 2 }) : '—'
  const shortAddr = a => a ? `${a.slice(0, 6)}…${a.slice(-4)}` : '—'

  return (
    <div style={{ maxWidth: 1140, margin: '0 auto', padding: '32px 24px' }}>
      <h1 style={{ fontFamily: 'var(--font-display)', color: 'var(--amber)', marginBottom: 8, fontSize: '1.4rem' }}>
        🏟 PvP Arena
      </h1>
      <p style={{ color: 'var(--muted)', marginBottom: 32, fontSize: '0.88rem' }}>
        Register your hero, get matched, and let Chainlink VRF decide the winner.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 32 }}>
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '20px 24px' }}>
          <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Entry Fee</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '1.4rem', color: 'var(--amber)' }}>{fmt(entryFee)} AETH</div>
        </div>
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '20px 24px' }}>
          <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Pending Reward</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '1.4rem', color: 'var(--amber)' }}>{fmt(pendingReward)} AETH</div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        {/* Register */}
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12, padding: 24 }}>
          <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--amber)', marginBottom: 20 }}>Register Hero</h2>
          <div style={{ marginBottom: 16 }}>
            <label style={{ fontSize: '0.78rem', color: 'var(--muted)', display: 'block', marginBottom: 6 }}>Hero Token ID</label>
            <input
              type="number" value={heroId} onChange={e => setHeroId(e.target.value)}
              placeholder="e.g. 1"
              style={{
                width: '100%', boxSizing: 'border-box',
                background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border)',
                borderRadius: 8, padding: '12px 14px',
                color: 'var(--text)', fontSize: '1rem', fontFamily: 'var(--font-display)',
              }}
            />
          </div>

          {txError && (
            <div style={{ background: 'rgba(220,50,50,0.1)', border: '1px solid #e05', borderRadius: 8, padding: '10px 14px', marginBottom: 12, color: '#f77', fontSize: '0.83rem' }}>
              {txError}
            </div>
          )}
          {isSuccess && (
            <div style={{ background: 'rgba(50,200,100,0.1)', border: '1px solid #3c6', borderRadius: 8, padding: '10px 14px', marginBottom: 12, color: '#6e6', fontSize: '0.83rem' }}>
              Registered! Waiting for opponent… ✓
            </div>
          )}

          <button
            onClick={handleRegister}
            disabled={!isConnected || !heroId || isPending || isConfirming}
            style={{
              width: '100%', padding: '14px',
              background: !isConnected || !heroId ? 'rgba(255,180,0,0.2)' : 'var(--amber)',
              color: !isConnected || !heroId ? 'var(--muted)' : '#000',
              border: 'none', borderRadius: 8,
              fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: '0.9rem',
              cursor: !isConnected || !heroId || isPending || isConfirming ? 'not-allowed' : 'pointer',
            }}
          >
            {isPending ? 'Confirm in wallet…' : isConfirming ? 'Confirming…' : 'Enter Arena'}
          </button>
        </div>

        {/* Active battles from subgraph */}
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12, padding: 24 }}>
          <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--amber)', marginBottom: 20 }}>
            Active Battles <span style={{ fontSize: '0.7rem', color: 'var(--muted)', fontFamily: 'var(--font-body)', fontWeight: 400 }}>via The Graph</span>
          </h2>
          {battles.length === 0 ? (
            <p style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>No active battles found in subgraph.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {battles.map(b => (
                <div key={b.id} style={{ border: '1px solid var(--border)', borderRadius: 8, padding: '12px 16px', fontSize: '0.82rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                    <span style={{ color: 'var(--muted)' }}>Battle #{b.id.slice(0, 6)}</span>
                    <span style={{ color: 'var(--amber)', fontSize: '0.72rem', textTransform: 'uppercase' }}>{b.status}</span>
                  </div>
                  <div style={{ color: 'var(--text)' }}>{shortAddr(b.player1)} vs {shortAddr(b.player2 || '?')}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
