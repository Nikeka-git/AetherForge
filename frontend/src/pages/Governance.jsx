import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useWaitForTransactionReceipt } from 'wagmi'
import { useGasWrite } from '../lib/useGasWrite.js'
import { formatEther } from 'viem'
import { ADDRESSES, AETH_ABI, GOVERNOR_ABI, GOVERNOR_STATES } from '../lib/contracts.js'
import { parseContractError } from '../lib/wagmi.js'

// Proposal IDs — loaded dynamically from ProposalCreated events on mount
const FALLBACK_IDS = [] // empty — all proposals loaded from chain

// ── ProposalCard ──────────────────────────────────────────────────────────────

function ProposalCard({ proposalId, userAddress, isConnected, title }) {
  const [txError, setTxError] = useState(null)
  const [support, setSupport] = useState(1)

  const { data: stateData } = useReadContract({
    address: ADDRESSES.AetherGovernor,
    abi: GOVERNOR_ABI,
    functionName: 'state',
    args: [BigInt(proposalId)] })

  const { data: votesData } = useReadContract({
    address: ADDRESSES.AetherGovernor,
    abi: GOVERNOR_ABI,
    functionName: 'proposalVotes',
    args: [BigInt(proposalId)] })

  const { data: hasVoted, refetch: refetchVoted } = useReadContract({
    address: ADDRESSES.AetherGovernor,
    abi: GOVERNOR_ABI,
    functionName: 'hasVoted',
    args: [BigInt(proposalId), userAddress],
    query: { enabled: isConnected && !!userAddress } })

  const { writeContractAsync, data: txHash, isPending } = useGasWrite()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })
  useEffect(() => { if (isSuccess) refetchVoted() }, [isSuccess])

  const stateInfo = stateData !== undefined ? GOVERNOR_STATES[Number(stateData)] : null
  const [against, forVotes, abstain] = votesData ?? [0n, 0n, 0n]
  const total = forVotes + against + abstain
  const forPct = total > 0n ? Number((forVotes * 100n) / total) : 0
  const shortId = proposalId.slice(0, 8) + '…'

  const stateColors = {
    'badge-active':    { bg: 'rgba(50,200,100,0.15)',  color: '#4c4' },
    'badge-pending':   { bg: 'rgba(255,180,0,0.15)',   color: 'var(--amber)' },
    'badge-succeeded': { bg: 'rgba(50,200,100,0.15)',  color: '#4c4' },
    'badge-defeated':  { bg: 'rgba(220,50,50,0.15)',   color: '#e55' },
    'badge-queued':    { bg: 'rgba(100,150,255,0.15)', color: '#88f' },
    'badge-executed':  { bg: 'rgba(100,150,255,0.15)', color: '#88f' },
    'badge-canceled':  { bg: 'rgba(120,120,120,0.15)', color: '#888' },
    'badge-expired':   { bg: 'rgba(120,120,120,0.15)', color: '#888' } }
  const sc = stateColors[stateInfo?.cls] ?? { bg: 'rgba(120,120,120,0.15)', color: '#888' }

  async function handleVote() {
    setTxError(null)
    try {
      await writeContractAsync({
        address: ADDRESSES.AetherGovernor,
        abi: GOVERNOR_ABI,
        functionName: 'castVote',
        args: [BigInt(proposalId), support] })
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
            {title || 'On-chain Proposal'}
          </div>
        </div>
        {stateInfo && (
          <span style={{ background: sc.bg, color: sc.color, border: `1px solid ${sc.color}`, borderRadius: 20, padding: '4px 12px', fontSize: '0.75rem', fontFamily: 'var(--font-display)', letterSpacing: '0.06em' }}>
            {stateInfo.label}
          </span>
        )}
      </div>

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

      {Number(stateData) === 1 && isConnected && !hasVoted && (
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          {[{ v: 1, label: '✓ For' }, { v: 0, label: '✗ Against' }, { v: 2, label: '○ Abstain' }].map(({ v, label }) => (
            <button key={v} onClick={() => setSupport(v)} style={{
              padding: '8px 16px', borderRadius: 6,
              background: support === v ? 'rgba(255,180,0,0.15)' : 'transparent',
              border: `1px solid ${support === v ? 'var(--amber)' : 'var(--border)'}`,
              color: support === v ? 'var(--amber)' : 'var(--muted)',
              fontSize: '0.82rem', cursor: 'pointer', fontFamily: 'var(--font-body)' }}>{label}</button>
          ))}
          <button onClick={handleVote} disabled={isPending || isConfirming} style={{
            padding: '8px 20px', borderRadius: 6,
            background: 'var(--amber)', color: '#000',
            border: 'none', fontFamily: 'var(--font-display)', fontWeight: 700,
            fontSize: '0.82rem', cursor: isPending || isConfirming ? 'wait' : 'pointer',
            letterSpacing: '0.05em' }}>
            {isPending ? 'Confirm…' : isConfirming ? 'Confirming…' : 'Cast Vote'}
          </button>
        </div>
      )}

      {hasVoted && Number(stateData) === 1 && (
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

// ── CreateProposal ────────────────────────────────────────────────────────────

function CreateProposal({ isConnected, onCreated }) {
  const [description, setDescription] = useState('')
  const [status, setStatus]   = useState(null) // null | 'pending' | 'success' | 'error'
  const [error, setError]     = useState(null)
  const [newId, setNewId]     = useState(null)

  const { writeContractAsync } = useGasWrite()
  // propose() args: targets[], values[], calldatas[], description
  // We send a no-op proposal (target = Governor itself, value = 0, calldata = 0x)
  // The description is the human-readable title shown on-chain.
  async function handleCreate() {
    if (!description.trim()) return
    setStatus('pending')
    setError(null)
    try {
      const hash = await writeContractAsync({
        address: ADDRESSES.AetherGovernor,
        abi: GOVERNOR_ABI,
        functionName: 'propose',
        args: [
          [ADDRESSES.AetherGovernor], // targets — self as no-op
          [0n],                        // values
          ['0x'],                      // calldatas
          description.trim(),          // description (becomes the proposal title)
        ] })
      setStatus('success')
      setDescription('')
      if (onCreated) onCreated(hash)
    } catch (e) {
      setStatus('error')
      setError(parseContractError(e))
    }
  }

  return (
    <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: 24, marginBottom: 32 }}>
      <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--amber)', marginBottom: 16 }}>
        📝 Create Proposal
      </h2>

      <div style={{ fontSize: '0.8rem', color: 'var(--muted)', marginBottom: 12 }}>
        Requires ≥ 1% voting power (1 000 000 AETH). Voting starts after a 1-day delay.
      </div>

      <textarea
        value={description}
        onChange={e => setDescription(e.target.value)}
        placeholder="Proposal title / description (e.g. 'Increase arena entry fee to 20 AETH')"
        rows={3}
        style={{
          width: '100%', boxSizing: 'border-box',
          background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border)',
          borderRadius: 8, padding: '12px 14px',
          color: 'var(--text)', fontSize: '0.9rem', resize: 'vertical',
          fontFamily: 'var(--font-body)', marginBottom: 12 }}
      />

      {error && (
        <div style={{ background: 'rgba(220,50,50,0.1)', border: '1px solid #e05', borderRadius: 8, padding: '8px 12px', marginBottom: 12, color: '#f77', fontSize: '0.82rem' }}>
          {error}
        </div>
      )}

      {status === 'success' && (
        <div style={{ background: 'rgba(50,200,100,0.1)', border: '1px solid #3c6', borderRadius: 8, padding: '8px 12px', marginBottom: 12, color: '#6e6', fontSize: '0.82rem' }}>
          ✓ Proposal submitted! It will appear as Pending after the transaction confirms.
        </div>
      )}

      <button
        onClick={handleCreate}
        disabled={!isConnected || !description.trim() || status === 'pending'}
        style={{
          padding: '12px 28px',
          background: !isConnected || !description.trim() ? 'rgba(255,180,0,0.2)' : 'var(--amber)',
          color: !isConnected || !description.trim() ? 'var(--muted)' : '#000',
          border: 'none', borderRadius: 8,
          fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: '0.88rem',
          cursor: !isConnected || !description.trim() || status === 'pending' ? 'not-allowed' : 'pointer',
          letterSpacing: '0.06em' }}
      >
        {status === 'pending' ? 'Submitting…' : 'Submit Proposal'}
      </button>
    </div>
  )
}

// ── Main Governance page ──────────────────────────────────────────────────────

export default function Governance() {
  const { address, isConnected } = useAccount()
  const [extraIds, setExtraIds] = useState([]) // proposals created during this session
  const [chainIds, setChainIds] = useState([])  // loaded from ProposalCreated events
  const [descriptions, setDescriptions] = useState({}) // proposalId -> description

  // Load all ProposalCreated events from the Governor on mount
  useEffect(() => {
    async function loadProposals() {
      try {
        const { createPublicClient, http } = await import('viem')
        const { arbitrumSepolia } = await import('viem/chains')
        const client = createPublicClient({ chain: arbitrumSepolia, transport: http() })
        const logs = await client.getLogs({
          address: ADDRESSES.AetherGovernor,
          event: {
            type: 'event',
            name: 'ProposalCreated',
            inputs: [
              { name: 'proposalId', type: 'uint256', indexed: false },
              { name: 'proposer', type: 'address', indexed: false },
              { name: 'targets', type: 'address[]', indexed: false },
              { name: 'values', type: 'uint256[]', indexed: false },
              { name: 'signatures', type: 'string[]', indexed: false },
              { name: 'calldatas', type: 'bytes[]', indexed: false },
              { name: 'voteStart', type: 'uint256', indexed: false },
              { name: 'voteEnd', type: 'uint256', indexed: false },
              { name: 'description', type: 'string', indexed: false },
            ] },
          fromBlock: 0n,
          toBlock: 'latest' })
        const ids = logs.map(l => l.args.proposalId.toString())
        const descMap = {}
        logs.forEach(l => {
          descMap[l.args.proposalId.toString()] = l.args.description || ''
        })
        setChainIds(ids)
        setDescriptions(descMap)
      } catch (e) {
        console.error('Failed to load proposals from chain:', e)
      }
    }
    loadProposals()
  }, [])

  const { data: votingPower } = useReadContract({
    address: ADDRESSES.AethToken,
    abi: AETH_ABI,
    functionName: 'getVotes',
    args: [address],
    query: { enabled: isConnected && !!address } })

  const { data: delegate } = useReadContract({
    address: ADDRESSES.AethToken,
    abi: AETH_ABI,
    functionName: 'delegates',
    args: [address],
    query: { enabled: isConnected && !!address } })

  const { writeContractAsync, data: delHash, isPending: delPending } = useGasWrite()
  const { isSuccess: delSuccess } = useWaitForTransactionReceipt({ hash: delHash })
  const [delegateInput, setDelegateInput] = useState('')

  async function handleDelegate() {
    const target = delegateInput.trim() || address
    await writeContractAsync({
      address: ADDRESSES.AethToken,
      abi: AETH_ABI,
      functionName: 'delegate',
      args: [target] })
  }

  const fmt = v => v !== undefined
    ? parseFloat(formatEther(v)).toLocaleString('en-US', { maximumFractionDigits: 2 })
    : '—'
  const shortAddr = a => a ? `${a.slice(0, 6)}…${a.slice(-4)}` : '—'

  const allIds = [...new Set([...chainIds, ...FALLBACK_IDS, ...extraIds])]

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
                borderRadius: 8, padding: '10px 14px', color: 'var(--text)', fontSize: '0.88rem' }}
            />
            <button onClick={handleDelegate} disabled={delPending} style={{
              padding: '10px 20px', background: 'var(--amber)', color: '#000',
              border: 'none', borderRadius: 8, fontFamily: 'var(--font-display)',
              fontWeight: 700, fontSize: '0.85rem', cursor: delPending ? 'wait' : 'pointer' }}>
              {delPending ? 'Confirming…' : 'Delegate'}
            </button>
          </div>
          {delSuccess && <div style={{ color: '#6e6', fontSize: '0.82rem', marginTop: 8 }}>Delegation updated! ✓</div>}
        </div>
      )}

      {/* Create Proposal */}
      {isConnected && (
        <CreateProposal
          isConnected={isConnected}
          onCreated={hash => {
            // proposal ID is computed off-chain as keccak256(abi.encode(targets,values,calldatas,keccak256(description)))
            // We can't easily recompute it here, so just prompt user to refresh
          }}
        />
      )}

      {/* Proposals list */}
      <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--amber)', marginBottom: 16 }}>
        Active Proposals
      </h2>

      {allIds.map(id => (
        <ProposalCard
          key={id}
          proposalId={id}
          userAddress={address}
          isConnected={isConnected}
          title={descriptions[id] || ""}
        />
      ))}

      <p style={{ color: 'var(--muted)', fontSize: '0.8rem', marginTop: 16 }}>
        Proposal IDs are loaded from the deployment. In production they are indexed via The Graph subgraph.
      </p>
    </div>
  )
}
