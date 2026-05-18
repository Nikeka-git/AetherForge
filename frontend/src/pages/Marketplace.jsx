import { useState } from 'react'
import { useAccount, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { ADDRESSES, AETH_ABI, AMM_ABI, RESOURCES } from '../lib/contracts.js'
import { parseContractError } from '../lib/wagmi.js'

export default function Marketplace() {
  const { address, isConnected } = useAccount()
  const [selectedItem, setSelectedItem] = useState(RESOURCES[0].id)
  const [direction, setDirection] = useState(true) // true = AETH→Item
  const [amountIn, setAmountIn] = useState('')
  const [minOut, setMinOut] = useState('')
  const [txError, setTxError] = useState(null)

  const resource = RESOURCES.find(r => r.id === selectedItem)

  const { data, refetch } = useReadContracts({
    contracts: [
      { address: ADDRESSES.AethToken,    abi: AETH_ABI, functionName: 'balanceOf', args: [address] },
      { address: ADDRESSES.AethToken,    abi: AETH_ABI, functionName: 'allowance', args: [address, ADDRESSES.AMMMarketplace] },
      { address: ADDRESSES.AMMMarketplace, abi: AMM_ABI, functionName: 'getReserves' },
    ],
    query: { enabled: isConnected && !!address },
  })

  const [aethBal, allowance, reserves] = data?.map(d => d.result) ?? []
  const reserveA = reserves?.[0]
  const reserveB = reserves?.[1]

  const { writeContract, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })
  if (isSuccess) refetch()

  const needsApproval = direction && amountIn && allowance !== undefined &&
    allowance < parseEther(amountIn || '0')

  async function handleSwap() {
    setTxError(null)
    try {
      const parsed = parseEther(amountIn)
      const minParsed = minOut ? parseEther(minOut) : 0n

      if (needsApproval) {
        writeContract({ address: ADDRESSES.AethToken, abi: AETH_ABI, functionName: 'approve', args: [ADDRESSES.AMMMarketplace, parsed] })
      } else {
        writeContract({
          address: ADDRESSES.AMMMarketplace,
          abi: AMM_ABI,
          functionName: 'swap',
          args: [direction, parsed, minParsed],
        })
      }
    } catch (e) {
      setTxError(parseContractError(e))
    }
  }

  const fmt = v => v !== undefined ? parseFloat(formatEther(v)).toLocaleString('en-US', { maximumFractionDigits: 4 }) : '—'

  return (
    <div style={{ maxWidth: 1140, margin: '0 auto', padding: '32px 24px' }}>
      <h1 style={{ fontFamily: 'var(--font-display)', color: 'var(--amber)', marginBottom: 8, fontSize: '1.4rem' }}>
        ⚖ Resource Marketplace
      </h1>
      <p style={{ color: 'var(--muted)', marginBottom: 32, fontSize: '0.88rem' }}>
        Swap AETH for in-game resources using the constant-product AMM.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 32 }}>
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '20px 24px' }}>
          <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Reserve AETH</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '1.2rem', color: 'var(--amber)' }}>{fmt(reserveA)}</div>
        </div>
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '20px 24px' }}>
          <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>Reserve Items</div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '1.2rem', color: 'var(--amber)' }}>{fmt(reserveB)}</div>
        </div>
      </div>

      <div style={{ maxWidth: 520, background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12, padding: 28 }}>
        {/* Direction toggle */}
        <div style={{ display: 'flex', gap: 8, marginBottom: 24 }}>
          {[true, false].map(d => (
            <button key={String(d)} onClick={() => setDirection(d)} style={{
              flex: 1, padding: '10px',
              background: direction === d ? 'rgba(255,180,0,0.15)' : 'transparent',
              border: `1px solid ${direction === d ? 'var(--amber)' : 'var(--border)'}`,
              borderRadius: 8, color: direction === d ? 'var(--amber)' : 'var(--muted)',
              fontFamily: 'var(--font-display)', fontSize: '0.82rem', cursor: 'pointer',
            }}>
              {d ? 'AETH → Item' : 'Item → AETH'}
            </button>
          ))}
        </div>

        <div style={{ marginBottom: 16 }}>
          <label style={{ fontSize: '0.78rem', color: 'var(--muted)', display: 'block', marginBottom: 6 }}>Amount In</label>
          <input
            type="number" value={amountIn} onChange={e => setAmountIn(e.target.value)}
            placeholder="0.0"
            style={{
              width: '100%', boxSizing: 'border-box',
              background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border)',
              borderRadius: 8, padding: '12px 14px',
              color: 'var(--text)', fontSize: '1.1rem', fontFamily: 'var(--font-display)',
            }}
          />
          <div style={{ fontSize: '0.75rem', color: 'var(--muted)', marginTop: 4 }}>
            AETH balance: {fmt(aethBal)}
          </div>
        </div>

        <div style={{ marginBottom: 20 }}>
          <label style={{ fontSize: '0.78rem', color: 'var(--muted)', display: 'block', marginBottom: 6 }}>Min Amount Out (slippage)</label>
          <input
            type="number" value={minOut} onChange={e => setMinOut(e.target.value)}
            placeholder="0.0"
            style={{
              width: '100%', boxSizing: 'border-box',
              background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border)',
              borderRadius: 8, padding: '12px 14px',
              color: 'var(--text)', fontSize: '1.1rem', fontFamily: 'var(--font-display)',
            }}
          />
        </div>

        {txError && (
          <div style={{ background: 'rgba(220,50,50,0.1)', border: '1px solid #e05', borderRadius: 8, padding: '10px 14px', marginBottom: 16, color: '#f77', fontSize: '0.83rem' }}>
            {txError}
          </div>
        )}

        {isSuccess && (
          <div style={{ background: 'rgba(50,200,100,0.1)', border: '1px solid #3c6', borderRadius: 8, padding: '10px 14px', marginBottom: 16, color: '#6e6', fontSize: '0.83rem' }}>
            Swap confirmed! ✓
          </div>
        )}

        <button
          onClick={handleSwap}
          disabled={!isConnected || !amountIn || isPending || isConfirming}
          style={{
            width: '100%', padding: '14px',
            background: !isConnected || !amountIn ? 'rgba(255,180,0,0.2)' : 'var(--amber)',
            color: !isConnected || !amountIn ? 'var(--muted)' : '#000',
            border: 'none', borderRadius: 8,
            fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: '0.9rem',
            cursor: !isConnected || !amountIn || isPending || isConfirming ? 'not-allowed' : 'pointer',
            letterSpacing: '0.06em',
          }}
        >
          {isPending ? 'Confirm in wallet…' :
           isConfirming ? 'Confirming…' :
           needsApproval ? 'Approve AETH' : 'Swap'}
        </button>
      </div>
    </div>
  )
}
