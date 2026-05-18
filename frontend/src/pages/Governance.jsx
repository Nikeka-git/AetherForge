import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { formatEther } from 'viem'
import { ADDRESSES, AETH_ABI, GOVERNOR_ABI, GOVERNOR_STATES } from '../lib/contracts.js'
import { parseContractError } from '../lib/wagmi.js'

// Known proposal IDs — in production these would come from The Graph
const DEMO_PROPOSAL_IDS = [
  '21563155559498266280527890826531012600993517765053769030078376762721975399025',
  '88328167418985655951777680462975474805839087562282088812088698975556754891273',
]

function ProposalCard({ proposalId, userAddress, isConnected }) {
  const [txError, setTxError] = useState(null)
  const [support, setSupport] = useState(1) // 0=against, 1=for, 2=abstain

  const { data: stateData } = useReadContract({
    address: ADDRESSES.AetherGovernor,
    abi: GOVERNOR_ABI,
    functionName: 'state',
    args: [BigInt(proposalId)],
  })

  const { data: votesData } = useReadContract({
    address: ADDRESSES.AetherGovernor,
    abi: GOVERNOR_ABI,
    functionName: 'proposalVotes',
    args: [BigInt(proposalId)],
  })

  const { data: hasVoted, refetch: refetchVoted } = useReadContract({
    address: ADDRESSES.AetherGovernor,
    abi: GOVERNOR_ABI,
    functionName: 'hasVoted',
    args: [BigInt(proposalId), userAddress],
    query: { enabled: isConnected && !!userAddress },
  })

  const { writeContract, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })
  if (isSuccess) refetchVoted()

  const stateInfo = stateData !== undefined ? GOVERNOR_STATES[stateData] : null
  const [against, forVotes, abstain] = votesData ?? [0n, 0n, 0n]
  const total = forVotes + against + abstain
  const forPct = total > 0n ? Number((forVotes * 100n) / total) : 0
  const shortId = proposalId.slice(0, 8) + '…'

  const stateColors = {
    'badge-active':    { bg: 'rgba(50,200,100,0.15)', color: '#4c4' },
    'badge-pending':   { bg: 'rgba(255,180,0,0.15)',  color: 'var(--amber)' },
    'badge-succeeded': { bg: 'rgba(50,200,100,0.15)', color: '#4c4' },
    'badge-defeated':  { bg: 'rgba(220,50,50,0.15)',  color: '#e55' },
    'badge-queued':    { bg: 'rgba(100,150,255,0.15)',color: '#88f' },
    'badge-executed':  { bg: 'rgba(100,150,255,0.15)',color: '#88f' },
    'badge-canceled':  { bg: 'rgba(120,120,120,0.15)',color: '#888' },
    'badge-expired':   { bg: 'rgba(120,120,120,0.15)',color: '#888' },
  }
  const sc = stateColors[stateInfo?.cls] ?? { bg: 'rgba(120,120,120,0.15)', color: '#888' }

  function handleVote() {
    setTxError(null)
    try {
      writeContract({
        address: ADDRESSES.AetherGovernor,
        abi: GOVERNOR_ABI,
        functionName: 'castVote',
        args: [BigInt(proposalId), support],
      })
    } catch (e) {
      setTxError(parseContractError(e))
    }
  }

  return (
    <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: 24, marginBottom: 16 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
        <div>
          <div style={{ fontSize: '0.72rem', color: 'var(--muted)', marginBottom: 4 }}>Proposal #{shortId}</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--text)' }}>
            On-chain Proposal
          </div>
        </div>
        {stateInfo && (
          <span style={{ background: sc.bg, color: sc.color, border: `1px solid ${sc.color}`, borderRadius: 20, padding: '4px 12px', fontSize: '0.75rem', fontFamily: 'var(--font-display)', letterSpacing: '0.06em' }}>
            {stateInfo.label}
          </span>
        )}
      </div>

      {/* Vote bar */}
      <div style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.78rem', color: 'var(--muted)', marginBottom: 6 }}>
          <span>For: {parseFloat(formatEther(forVotes ?? 0n)).toFixed(2)}</span>
          <span>Against: {parseFloat(formatEther(against ?? 0n)).toFixed(2)}</span>
          <span>Abstain: {parseFloat(formatEther(abstain ?? 0n)).toFixed(2)}</span>
        </div>
        <div style={{ height: 6, background: 'rgba(255,255,255,0.08)', borderRadius: 3, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${forPct}%`, background: 'var(--amber)', transition: 'width 0.4s' }} />
        </div>
      </div>

      {/* Vote controls — only show if Active */}
      {stateData === 1 && isConnected && !hasVoted && (
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          {[{ v: 1, label: '✓ For' }, { v: 0, label: '✗ Against' }, { v: 2, label: '○ Abstain' }].map(({ v, label }) => (
            <button key={v} onClick={() => setSupport(v)} style={{
              padding: '8px 16px', borderRadius: 6,
              background: support === v ? 'rgba(255,180,0,0.15)' : 'transparent',
              border: `1px solid ${support === v ? 'var(--amber)' : 'var(--border)'}`,
              color: support === v ? 'var(--amber)' : 'var(--muted)',
              fontSize: '0.82rem', cursor: 'pointer', fontFamily: 'var(--font-body)',
            }}>{label}</button>
          ))}
          <button
            onClick={handleVote}
            disabled={isPending || isConfirming}
            style={{
              padding: '8px 20px', borderRadius: 6,
              background: 'var(--amber)', color: '#000',
              border: 'none', fontFamily: 'var(--font-display)', fontWeight: 700,
              fontSize: '0.82rem', cursor: isPending || isConfirming ? 'wait' : 'pointer',
              letterSpacing: '0.05em',
            }}
          >
            {isPending ? 'Confirm…' : isConfirming ? 'Confirming…' : 'Cast Vote'}
          </button>
        </div>
      )}

      {hasVoted && stateData === 1 && (
        <div style={{ fontSize: '0.82rem', color: '#6e6' }}>✓ You have already voted on this proposal</div>
      )}

      {txError && (
        <div style={{ background: 'rgba(220,50,50,0.1)', border: '1px solid #e05', borderRadius: 8, padding: '8px 12px', marginTop: 12, color: '#f77', fontSize: '0.82rem' }}>
          {txError}
        </div>
      )}

      {isSuccess && (
        <div style={{ background: 'rgba(50,200,100,0.1)', border: '1px solid #3c6', borderRadius: 8, padding: '8px 12px', marginTop: 12, color: '#6e6', fontSize: '0.82rem' }}>
          Vote cast successfully! ✓
        </div>
      )}
    </div>
  )
}

export default function Governance() {
  const { address, isConnected } = useAccount()

  const { data: votingPower } = useReadContract({
    address: ADDRESSES.AethToken,
    abi: AETH_ABI,
    functionName: 'getVotes',
    args: [address],
    query: { enabled: isConnected && !!address },
  })

  const { data: delegate } = useReadContract({
    address: ADDRESSES.AethToken,
    abi: AETH_ABI,
    functionName: 'delegates',
    args: [address],
    query: { enabled: isConnected && !!address },
  })

  const { writeContract, data: delHash, isPending: delPending } = useWriteContract()
  const { isSuccess: delSuccess } = useWaitForTransactionReceipt({ hash: delHash })
  const [delegateInput, setDelegateInput] = useState('')

  function handleDelegate() {
    const target = delegateInput.trim() || address
    writeContract({ address: ADDRESSES.AethToken, abi: AETH_ABI, functionName: 'delegate', args: [target] })
  }

  const fmt = v => v !== undefined ? parseFloat(formatEther(v)).toLocaleString('en-US', { maximumFractionDigits: 2 }) : '—'
  const shortAddr = a => a ? `${a.slice(0, 6)}…${a.slice(-4)}` : '—'

  return (
    <div style={{ maxWidth: 1140, margin: '0 auto', padding: '32px 24px' }}>
      <h1 style={{ fontFamily: 'var(--font-display)', color: 'var(--amber)', marginBottom: 8, fontSize: '1.4rem' }}>
        ⚖️ DAO Governance
      </h1>
      <p style={{ color: 'var(--muted)', marginBottom: 32, fontSize: '0.88rem' }}>
        Vote on proposals that govern AetherForge Arena parameters.
      </p>

      {/* Voter info */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 32 }}>
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '20px 24px' }}>
          <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Your Voting Power</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '1.4rem', color: 'var(--amber)' }}>{fmt(votingPower)} AETH</div>
        </div>
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '20px 24px' }}>
          <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Delegated To</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--text)' }}>{shortAddr(delegate)}</div>
          {delegate && address && delegate.toLowerCase() === address.toLowerCase() && (
            <div style={{ fontSize: '0.72rem', color: 'var(--muted)', marginTop: 2 }}>self-delegated</div>
          )}
        </div>
      </div>

      {/* Delegate control */}
      {isConnected && (
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: 20, marginBottom: 32 }}>
          <div style={{ fontSize: '0.82rem', color: 'var(--muted)', marginBottom: 12 }}>
            Delegate voting power (leave blank to self-delegate)
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <input
              value={delegateInput} onChange={e => setDelegateInput(e.target.value)}
              placeholder="0x… or leave blank for self"
              style={{
                flex: 1, background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border)',
                borderRadius: 8, padding: '10px 14px', color: 'var(--text)', fontSize: '0.88rem',
              }}
            />
            <button onClick={handleDelegate} disabled={delPending} style={{
              padding: '10px 20px', background: 'var(--amber)', color: '#000',
              border: 'none', borderRadius: 8, fontFamily: 'var(--font-display)',
              fontWeight: 700, fontSize: '0.85rem', cursor: delPending ? 'wait' : 'pointer',
            }}>
              {delPending ? 'Confirming…' : 'Delegate'}
            </button>
          </div>
          {delSuccess && <div style={{ color: '#6e6', fontSize: '0.82rem', marginTop: 8 }}>Delegation updated! ✓</div>}
        </div>
      )}

      {/* Proposals */}
      <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--amber)', marginBottom: 16 }}>
        Active Proposals
      </h2>

      {DEMO_PROPOSAL_IDS.map(id => (
        <ProposalCard
          key={id}
          proposalId={id}
          userAddress={address}
          isConnected={isConnected}
        />
      ))}

      <p style={{ color: 'var(--muted)', fontSize: '0.8rem', marginTop: 16 }}>
        Proposal IDs are loaded from the deployment. In production they are indexed via The Graph subgraph.
      </p>
    </div>
  )
}
