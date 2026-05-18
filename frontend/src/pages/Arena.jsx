import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { formatEther } from 'viem'
import { ADDRESSES, ARENA_ABI } from '../lib/contracts.js'
import { parseContractError } from '../lib/wagmi.js'
import { fetchActiveBattles } from '../lib/subgraph.js'

const BATTLE_STATES = ['Idle', 'Registered', 'Matched', 'Resolved', 'Cancelled']
const STATE_COLORS = {
  Idle:       { color: 'var(--muted)',  border: 'var(--border)' },
  Registered: { color: '#ffb400',       border: '#ffb400' },
  Matched:    { color: '#88aaff',       border: '#88aaff' },
  Resolved:   { color: '#44cc77',       border: '#44cc77' },
  Cancelled:  { color: '#cc4444',       border: '#cc4444' },
}

// Reads a single battle by ID and shows it with Claim button if won
function BattleCard({ battleId, userAddress, onClaimed }) {
  const { data: battle, refetch } = useReadContract({
    address: ADDRESSES.PvPArena,
    abi: ARENA_ABI,
    functionName: 'getBattle',
    args: [BigInt(battleId)],
  })

  const { data: reward } = useReadContract({
    address: ADDRESSES.PvPArena,
    abi: ARENA_ABI,
    functionName: 'pendingRewards',
    args: [BigInt(battleId)],
    query: { enabled: !!battle },
  })

  const { writeContract, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  useEffect(() => {
    if (isSuccess) { refetch(); onClaimed?.() }
  }, [isSuccess])

  if (!battle) return null

  const stateName = BATTLE_STATES[battle.state] ?? 'Unknown'
  const sc = STATE_COLORS[stateName] ?? STATE_COLORS.Idle
  const isWinner = battle.winner?.toLowerCase() === userAddress?.toLowerCase()
  const canClaim = stateName === 'Resolved' && isWinner && !battle.claimed
  const fmt = v => v !== undefined ? parseFloat(formatEther(v)).toFixed(2) : '—'
  const shortAddr = a => a ? `${a.slice(0, 6)}…${a.slice(-4)}` : '?'

  return (
    <div style={{
      border: `1px solid ${canClaim ? '#44cc77' : 'var(--border)'}`,
      borderRadius: 10,
      padding: '16px 20px',
      background: canClaim ? 'rgba(50,200,100,0.05)' : 'var(--surface)',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
        <span style={{ fontFamily: 'var(--font-display)', fontSize: '0.85rem', color: 'var(--text)' }}>
          Battle #{battleId}
        </span>
        <span style={{
          background: `${sc.color}22`, border: `1px solid ${sc.border}`,
          color: sc.color, borderRadius: 20, padding: '3px 10px',
          fontSize: '0.72rem', fontFamily: 'var(--font-display)', letterSpacing: '0.06em',
        }}>
          {stateName}
        </span>
      </div>

      <div style={{ fontSize: '0.82rem', color: 'var(--muted)', marginBottom: 8 }}>
        {shortAddr(battle.player1)} <span style={{ color: 'var(--amber)' }}>vs</span> {shortAddr(battle.player2)}
      </div>

      {stateName === 'Resolved' && (
        <div style={{ fontSize: '0.82rem', marginBottom: 10 }}>
          <span style={{ color: 'var(--muted)' }}>Winner: </span>
          <span style={{ color: isWinner ? '#44cc77' : 'var(--text)', fontFamily: 'var(--font-display)' }}>
            {isWinner ? '🏆 You!' : shortAddr(battle.winner)}
          </span>
          {reward !== undefined && reward > 0n && (
            <span style={{ color: 'var(--amber)', marginLeft: 12 }}>
              {fmt(reward)} AETH
            </span>
          )}
          {battle.claimed && (
            <span style={{ color: 'var(--muted)', marginLeft: 8, fontSize: '0.75rem' }}>(claimed)</span>
          )}
        </div>
      )}

      {canClaim && (
        <button
          onClick={() => writeContract({
            address: ADDRESSES.PvPArena,
            abi: ARENA_ABI,
            functionName: 'claimReward',
            args: [BigInt(battleId)],
          })}
          disabled={isPending || isConfirming}
          style={{
            width: '100%', padding: '10px',
            background: '#44cc77', color: '#000',
            border: 'none', borderRadius: 8,
            fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: '0.88rem',
            cursor: isPending || isConfirming ? 'wait' : 'pointer',
            letterSpacing: '0.05em',
          }}
        >
          {isPending ? 'Confirm in wallet…' : isConfirming ? 'Confirming…' : `Claim ${fmt(reward)} AETH`}
        </button>
      )}

      {isSuccess && (
        <div style={{ color: '#44cc77', fontSize: '0.82rem', marginTop: 8 }}>Reward claimed! ✓</div>
      )}
    </div>
  )
}

export default function Arena() {
  const { address, isConnected } = useAccount()
  const [heroId, setHeroId] = useState('')
  const [battleIdInput, setBattleIdInput] = useState('1')
  const [trackedBattles, setTrackedBattles] = useState(['1'])
  const [txError, setTxError] = useState(null)
  const [subgraphBattles, setSubgraphBattles] = useState([])

  const { data: entryFee } = useReadContract({
    address: ADDRESSES.PvPArena,
    abi: ARENA_ABI,
    functionName: 'entryFee',
  })

  const { writeContract, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  useEffect(() => {
    fetchActiveBattles().then(setSubgraphBattles).catch(() => {})
  }, [])

  // After register success, add the new battle to tracked list
  useEffect(() => {
    if (isSuccess) {
      // next battle id = current tracked + 1 (approximation; user can also add manually)
    }
  }, [isSuccess])

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

  function addBattle() {
    const id = battleIdInput.trim()
    if (id && !trackedBattles.includes(id)) {
      setTrackedBattles(prev => [...prev, id])
    }
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

      {/* Entry fee */}
      <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '20px 24px', display: 'inline-block', marginBottom: 32 }}>
        <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Entry Fee</div>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: '1.4rem', color: 'var(--amber)' }}>{fmt(entryFee)} AETH</div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24, marginBottom: 32 }}>
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
          {subgraphBattles.length === 0 ? (
            <p style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>No active battles in subgraph.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {subgraphBattles.map(b => (
                <div key={b.id} style={{ border: '1px solid var(--border)', borderRadius: 8, padding: '12px 16px', fontSize: '0.82rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                    <span style={{ color: 'var(--muted)' }}>Battle #{b.id}</span>
                    <span style={{ color: 'var(--amber)', fontSize: '0.72rem', textTransform: 'uppercase' }}>{b.status}</span>
                  </div>
                  <div style={{ color: 'var(--text)' }}>{shortAddr(b.player1)} vs {shortAddr(b.player2 || '?')}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* My Battles — track by ID, show results and Claim */}
      <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12, padding: 24 }}>
        <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--amber)', marginBottom: 8 }}>
          My Battles
        </h2>
        <p style={{ color: 'var(--muted)', fontSize: '0.82rem', marginBottom: 20 }}>
          Track your battles by ID. If you won, claim your reward here.
        </p>

        {/* Add battle by ID */}
        <div style={{ display: 'flex', gap: 8, marginBottom: 24 }}>
          <input
            type="number"
            value={battleIdInput}
            onChange={e => setBattleIdInput(e.target.value)}
            placeholder="Battle ID"
            style={{
              flex: 1, background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border)',
              borderRadius: 8, padding: '10px 14px', color: 'var(--text)',
              fontSize: '0.9rem', fontFamily: 'var(--font-display)',
            }}
          />
          <button
            onClick={addBattle}
            style={{
              padding: '10px 20px', background: 'rgba(255,180,0,0.15)',
              border: '1px solid var(--amber)', borderRadius: 8,
              color: 'var(--amber)', fontFamily: 'var(--font-display)',
              fontSize: '0.85rem', cursor: 'pointer',
            }}
          >
            Track Battle
          </button>
        </div>

        {trackedBattles.length === 0 ? (
          <p style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>No battles tracked yet.</p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {trackedBattles.map(id => (
              <BattleCard key={id} battleId={id} userAddress={address} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
