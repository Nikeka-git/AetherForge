import { useState, useEffect } from 'react'
import { useAccount, useWaitForTransactionReceipt, useReadContract } from 'wagmi'
import { useGasWrite } from '../lib/useGasWrite.js'
import { ADDRESSES, CRAFTING_ABI, AETH_ABI, RECIPES } from '../lib/contracts.js'
import { parseContractError } from '../lib/wagmi.js'

export default function Forge() {
  const { address, isConnected } = useAccount()
  const [selected, setSelected] = useState(null)
  const [txError, setTxError] = useState(null)

  const { writeContract: writeApprove, data: approveTxHash, isPending: isApprovePending } = useGasWrite()
  const { writeContract, data: txHash, isPending } = useGasWrite()
  const { isLoading: isConfirmingApprove, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({ hash: approveTxHash })
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  const { data: aethAllowance, refetch: refetchAllowance } = useReadContract({
    address: ADDRESSES.AethToken,
    abi: AETH_ABI,
    functionName: 'allowance',
    args: [address, ADDRESSES.CraftingEngine],
    query: { enabled: isConnected && !!address } })

  useEffect(() => {
    if (isApproveSuccess) refetchAllowance()
  }, [isApproveSuccess])

  function handleCraft() {
    setTxError(null)
    try {
      if (!recipe) return
      if (aethAllowance === undefined) return
      // Approve a generous fixed amount (10 000 AETH) so the craft goes through.
      // The contract oracle determines exact AETH cost at execution time.
      const APPROVE_AMOUNT = BigInt(10_000) * BigInt(1e18)
      if (aethAllowance < APPROVE_AMOUNT / 10n) {
        writeApprove({
          address: ADDRESSES.AethToken,
          abi: AETH_ABI,
          functionName: 'approve',
          args: [ADDRESSES.CraftingEngine, APPROVE_AMOUNT],
        })
      } else {
        writeContract({
          address: ADDRESSES.CraftingEngine,
          abi: CRAFTING_ABI,
          functionName: 'craft',
          args: [BigInt(selected)] })
      }
    } catch (e) {
      setTxError(parseContractError(e))
    }
  }

  const recipe = RECIPES.find(r => r.id === selected)

  return (
    <div style={{ maxWidth: 1140, margin: '0 auto', padding: '32px 24px' }}>
      <h1 style={{ fontFamily: 'var(--font-display)', color: 'var(--amber)', marginBottom: 8, fontSize: '1.4rem' }}>
        🔥 Crafting Forge
      </h1>
      <p style={{ color: 'var(--muted)', marginBottom: 32, fontSize: '0.88rem' }}>
        Combine resources to forge powerful equipment. AETH is burned as a crafting fee.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16, marginBottom: 32 }}>
        {RECIPES.map(r => (
          <div
            key={r.id}
            onClick={() => setSelected(r.id)}
            style={{
              background: selected === r.id ? 'rgba(255,180,0,0.08)' : 'var(--surface)',
              border: `1px solid ${selected === r.id ? 'var(--amber)' : 'var(--border)'}`,
              borderRadius: 10, padding: 20, cursor: 'pointer',
              transition: 'all 180ms ease' }}
          >
            <div style={{ fontSize: '2rem', marginBottom: 10 }}>{r.icon}</div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--text)', marginBottom: 8 }}>{r.name}</div>
            <div style={{ fontSize: '0.78rem', color: 'var(--muted)', marginBottom: 12 }}>
              {r.ingredients.map(ing => `${ing.amount}× ${ing.name}`).join(', ')}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>AETH Cost</span>
              <span style={{ fontFamily: 'var(--font-display)', color: 'var(--amber)', fontSize: '0.9rem' }}>${r.usdCost} USD</span>
            </div>
          </div>
        ))}
      </div>

      {recipe && (
        <div style={{ maxWidth: 460, background: 'var(--surface)', border: '1px solid var(--amber)', borderRadius: 12, padding: 28 }}>
          <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--amber)', marginBottom: 16 }}>
            {recipe.icon} Craft {recipe.name}
          </h2>
          <div style={{ marginBottom: 16 }}>
            <div style={{ fontSize: '0.78rem', color: 'var(--muted)', marginBottom: 8 }}>Ingredients required:</div>
            {recipe.ingredients.map(ing => (
              <div key={ing.itemId} style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px solid rgba(255,255,255,0.05)', fontSize: '0.85rem' }}>
                <span style={{ color: 'var(--text)' }}>{ing.name}</span>
                <span style={{ color: 'var(--amber)' }}>×{ing.amount}</span>
              </div>
            ))}
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', fontSize: '0.85rem' }}>
              <span style={{ color: 'var(--muted)' }}>AETH fee</span>
              <span style={{ color: 'var(--amber)', fontFamily: 'var(--font-display)' }}>${recipe.usdCost} USD</span>
            </div>
          </div>

          {txError && (
            <div style={{ background: 'rgba(220,50,50,0.1)', border: '1px solid #e05', borderRadius: 8, padding: '10px 14px', marginBottom: 16, color: '#f77', fontSize: '0.83rem' }}>
              {txError}
            </div>
          )}
          {isSuccess && (
            <div style={{ background: 'rgba(50,200,100,0.1)', border: '1px solid #3c6', borderRadius: 8, padding: '10px 14px', marginBottom: 16, color: '#6e6', fontSize: '0.83rem' }}>
              {recipe.name} crafted successfully! ✓
            </div>
          )}

          <button
            onClick={handleCraft}
            disabled={!isConnected || isPending || isConfirming}
            style={{
              width: '100%', padding: '14px',
              background: !isConnected ? 'rgba(255,180,0,0.2)' : 'var(--amber)',
              color: !isConnected ? 'var(--muted)' : '#000',
              border: 'none', borderRadius: 8,
              fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: '0.9rem',
              cursor: !isConnected || isPending || isConfirming ? 'not-allowed' : 'pointer',
              letterSpacing: '0.06em' }}
          >
            {isPending ? 'Confirm in wallet…' : isConfirming ? 'Confirming…' : `Forge ${recipe.name}`}
          </button>
        </div>
      )}
    </div>
  )
}
