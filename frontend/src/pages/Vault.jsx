import { useState } from 'react'
import { useAccount, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { ADDRESSES, AETH_ABI, TREASURY_ABI } from '../lib/contracts.js'
import { parseContractError } from '../lib/wagmi.js'

export default function Vault() {
  const { address, isConnected } = useAccount()
  const [tab, setTab] = useState('deposit') // 'deposit' | 'redeem'
  const [amount, setAmount] = useState('')
  const [txError, setTxError] = useState(null)

  const { data, refetch } = useReadContracts({
    contracts: [
      { address: ADDRESSES.AethToken,    abi: AETH_ABI,    functionName: 'balanceOf',   args: [address] },
      { address: ADDRESSES.AethToken,    abi: AETH_ABI,    functionName: 'allowance',   args: [address, ADDRESSES.GuildTreasury] },
      { address: ADDRESSES.GuildTreasury, abi: TREASURY_ABI, functionName: 'balanceOf', args: [address] },
      { address: ADDRESSES.GuildTreasury, abi: TREASURY_ABI, functionName: 'totalAssets' },
      { address: ADDRESSES.GuildTreasury, abi: TREASURY_ABI, functionName: 'totalSupply' },
    ],
    query: { enabled: isConnected && !!address },
  })

  const [aethBal, allowance, shares, totalAssets, totalShares] = data?.map(d => d.result) ?? []

  const { writeContract, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  if (isSuccess) { refetch(); }

  const needsApproval = tab === 'deposit' && amount && allowance !== undefined &&
    allowance < parseEther(amount || '0')

  async function handleSubmit() {
    setTxError(null)
    try {
      const parsed = parseEther(amount)
      if (needsApproval) {
        writeContract({
          address: ADDRESSES.AethToken,
          abi: AETH_ABI,
          functionName: 'approve',
          args: [ADDRESSES.GuildTreasury, parsed],
        })
      } else if (tab === 'deposit') {
        writeContract({
          address: ADDRESSES.GuildTreasury,
          abi: TREASURY_ABI,
          functionName: 'deposit',
          args: [parsed, address],
        })
      } else {
        writeContract({
          address: ADDRESSES.GuildTreasury,
          abi: TREASURY_ABI,
          functionName: 'redeem',
          args: [parsed, address, address],
        })
      }
    } catch (e) {
      setTxError(parseContractError(e))
    }
  }

  const fmt = v => v !== undefined ? parseFloat(formatEther(v)).toLocaleString('en-US', { maximumFractionDigits: 4 }) : '—'
  const sharePrice = totalAssets && totalShares && totalShares > 0n
    ? parseFloat(formatEther(totalAssets)) / parseFloat(formatEther(totalShares))
    : 1

  return (
    <div style={{ maxWidth: 1140, margin: '0 auto', padding: '32px 24px' }}>
      <h1 style={{ fontFamily: 'var(--font-display)', color: 'var(--amber)', marginBottom: 8, fontSize: '1.4rem' }}>
        🏦 Guild Treasury Vault
      </h1>
      <p style={{ color: 'var(--muted)', marginBottom: 32, fontSize: '0.88rem' }}>
        Deposit AETH to earn yield. Withdraw anytime by redeeming shares.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16, marginBottom: 32 }}>
        {[
          { label: 'Total Assets', value: `${fmt(totalAssets)} AETH` },
          { label: 'Share Price',  value: `${sharePrice.toFixed(6)} AETH` },
          { label: 'Your Shares',  value: fmt(shares) },
        ].map(({ label, value }) => (
          <div key={label} style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '20px 24px' }}>
            <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>{label}</div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: '1.2rem', color: 'var(--amber)' }}>{value}</div>
          </div>
        ))}
      </div>

      <div style={{ maxWidth: 480, background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12, padding: 28 }}>
        {/* Tabs */}
        <div style={{ display: 'flex', marginBottom: 24, borderBottom: '1px solid var(--border)' }}>
          {['deposit', 'redeem'].map(t => (
            <button key={t} onClick={() => { setTab(t); setAmount(''); setTxError(null) }} style={{
              flex: 1, padding: '10px', background: 'transparent', border: 'none',
              borderBottom: tab === t ? '2px solid var(--amber)' : '2px solid transparent',
              color: tab === t ? 'var(--amber)' : 'var(--muted)',
              fontFamily: 'var(--font-display)', fontSize: '0.85rem', cursor: 'pointer',
              textTransform: 'uppercase', letterSpacing: '0.08em',
            }}>{t}</button>
          ))}
        </div>

        <div style={{ marginBottom: 8, fontSize: '0.8rem', color: 'var(--muted)' }}>
          {tab === 'deposit' ? `Balance: ${fmt(aethBal)} AETH` : `Shares: ${fmt(shares)}`}
        </div>

        <div style={{ position: 'relative', marginBottom: 20 }}>
          <input
            type="number"
            value={amount}
            onChange={e => setAmount(e.target.value)}
            placeholder="0.0"
            style={{
              width: '100%', boxSizing: 'border-box',
              background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border)',
              borderRadius: 8, padding: '12px 80px 12px 14px',
              color: 'var(--text)', fontSize: '1.1rem', fontFamily: 'var(--font-display)',
            }}
          />
          <button
            onClick={() => setAmount(formatEther(tab === 'deposit' ? (aethBal ?? 0n) : (shares ?? 0n)))}
            style={{
              position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)',
              background: 'rgba(255,180,0,0.15)', border: '1px solid var(--amber)',
              borderRadius: 4, padding: '4px 10px', color: 'var(--amber)',
              fontSize: '0.72rem', cursor: 'pointer', fontFamily: 'var(--font-display)',
            }}
          >MAX</button>
        </div>

        {txError && (
          <div style={{ background: 'rgba(220,50,50,0.1)', border: '1px solid #e05', borderRadius: 8, padding: '10px 14px', marginBottom: 16, color: '#f77', fontSize: '0.83rem' }}>
            {txError}
          </div>
        )}

        {isSuccess && (
          <div style={{ background: 'rgba(50,200,100,0.1)', border: '1px solid #3c6', borderRadius: 8, padding: '10px 14px', marginBottom: 16, color: '#6e6', fontSize: '0.83rem' }}>
            Transaction confirmed! ✓
          </div>
        )}

        <button
          onClick={handleSubmit}
          disabled={!isConnected || !amount || isPending || isConfirming}
          style={{
            width: '100%', padding: '14px',
            background: !isConnected || !amount ? 'rgba(255,180,0,0.2)' : 'var(--amber)',
            color: !isConnected || !amount ? 'var(--muted)' : '#000',
            border: 'none', borderRadius: 8,
            fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: '0.9rem',
            cursor: !isConnected || !amount || isPending || isConfirming ? 'not-allowed' : 'pointer',
            letterSpacing: '0.06em',
          }}
        >
          {isPending ? 'Confirm in wallet…' :
           isConfirming ? 'Confirming…' :
           needsApproval ? 'Approve AETH' :
           tab === 'deposit' ? 'Deposit AETH' : 'Redeem Shares'}
        </button>
      </div>
    </div>
  )
}
