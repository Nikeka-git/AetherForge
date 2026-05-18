import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useReadContracts, useWaitForTransactionReceipt } from 'wagmi'
import { createPublicClient, http } from 'viem'
import { arbitrumSepolia } from 'viem/chains'
import { ADDRESSES, HERO_ABI, HERO_CLASSES, HERO_CLASS_ICONS } from '../lib/contracts.js'
import { useGasWrite } from '../lib/useGasWrite.js'

const cardStyle = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 10,
  padding: 28,
  marginBottom: 24,
}
const labelStyle = {
  fontSize: '0.72rem', color: 'var(--muted)',
  textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 4,
}
const inputStyle = {
  width: '100%', background: 'rgba(255,255,255,0.04)',
  border: '1px solid var(--border)', borderRadius: 6,
  padding: '10px 14px', color: 'var(--text)', fontSize: '0.9rem', boxSizing: 'border-box',
}
const btnStyle = (disabled) => ({
  width: '100%', padding: '12px 0', borderRadius: 6, border: 'none',
  cursor: disabled ? 'not-allowed' : 'pointer',
  fontFamily: 'var(--font-display)', fontSize: '0.85rem', letterSpacing: '0.08em',
  background: disabled ? '#3a2f10' : 'linear-gradient(90deg,#c47f17,#e5a020)',
  color: disabled ? '#7a6030' : '#0d0d14',
  transition: 'opacity 0.15s', marginTop: 16,
})

// Загружает все ID героев принадлежащих адресу
async function fetchOwnedHeroes(ownerAddress) {
  const client = createPublicClient({ chain: arbitrumSepolia, transport: http() })

  // Узнаём сколько всего героев наминтили
  const totalMinted = await client.readContract({
    address: ADDRESSES.HeroNFT,
    abi: HERO_ABI,
    functionName: 'totalMinted',
  })

  if (!totalMinted || totalMinted === 0n) return []

  // Запрашиваем ownerOf для всех токенов батчем
  const calls = Array.from({ length: Number(totalMinted) }, (_, i) => ({
    address: ADDRESSES.HeroNFT,
    abi: HERO_ABI,
    functionName: 'ownerOf',
    args: [BigInt(i + 1)],
  }))

  const results = await client.multicall({ contracts: calls })

  // Фильтруем только те, что принадлежат нашему адресу
  const ownedIds = []
  results.forEach((res, i) => {
    if (res.status === 'success' &&
        res.result?.toLowerCase() === ownerAddress.toLowerCase()) {
      ownedIds.push(i + 1) // tokenId начинается с 1
    }
  })

  if (ownedIds.length === 0) return []

  // Загружаем атрибуты для каждого героя
  const attrCalls = ownedIds.map(id => ({
    address: ADDRESSES.HeroNFT,
    abi: HERO_ABI,
    functionName: 'getHeroAttributes',
    args: [BigInt(id)],
  }))

  const attrResults = await client.multicall({ contracts: attrCalls })

  return ownedIds.map((id, i) => {
    const attrs = attrResults[i].status === 'success' ? attrResults[i].result : null
    return {
      id,
      level:     attrs ? Number(Array.isArray(attrs) ? attrs[0] : attrs.level) : 1,
      heroClass: attrs ? Number(Array.isArray(attrs) ? attrs[1] : attrs.heroClass) : 0,
    }
  })
}

export default function Heroes() {
  const { address, isConnected } = useAccount()
  const [recipient, setRecipient] = useState('')
  const [selectedClass, setSelectedClass] = useState(0)
  const [mintStatus, setMintStatus] = useState(null)
  const [mintError, setMintError] = useState('')
  const [ownedHeroes, setOwnedHeroes] = useState([])
  const [loadingHeroes, setLoadingHeroes] = useState(false)

  const { writeContractAsync } = useGasWrite()
  const [txHash, setTxHash] = useState(null)

  const { isLoading: isTxPending, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
    query: { enabled: !!txHash },
  })

  // Загружаем героев при подключении и после минта
  async function loadHeroes() {
    if (!address) return
    setLoadingHeroes(true)
    try {
      const heroes = await fetchOwnedHeroes(address)
      setOwnedHeroes(heroes)
    } catch (e) {
      console.error('Failed to load heroes:', e)
    } finally {
      setLoadingHeroes(false)
    }
  }

  useEffect(() => {
    if (isConnected && address) loadHeroes()
  }, [address, isConnected])

  useEffect(() => {
    if (isTxSuccess) {
      setMintStatus('success')
      setTxHash(null)
      loadHeroes()
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
      setMintError(err?.shortMessage || err?.message || 'Transaction failed')
    }
  }

  const isBusy = mintStatus === 'pending' || isTxPending

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
          {/* ── Список героев ── */}
          <div style={cardStyle}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '0.9rem', color: 'var(--amber)', textTransform: 'uppercase', letterSpacing: '0.1em', margin: 0 }}>
                Your Heroes ({ownedHeroes.length})
              </h2>
              <button onClick={loadHeroes} disabled={loadingHeroes} style={{
                background: 'transparent', border: '1px solid var(--border)',
                color: 'var(--muted)', borderRadius: 6, padding: '4px 10px',
                fontSize: '0.75rem', cursor: loadingHeroes ? 'wait' : 'pointer',
                fontFamily: 'var(--font-body)',
              }}>
                {loadingHeroes ? 'Loading…' : '↻ Refresh'}
              </button>
            </div>

            {loadingHeroes ? (
              <div style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>Loading heroes…</div>
            ) : ownedHeroes.length === 0 ? (
              <div style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>
                You don't own any heroes yet. Mint one below!
              </div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 }}>
                {ownedHeroes.map(hero => (
                  <div key={hero.id} style={{
                    border: '1px solid var(--border)', borderRadius: 10,
                    padding: '16px 12px', textAlign: 'center',
                    background: 'rgba(255,255,255,0.02)',
                  }}>
                    <div style={{ fontSize: '2rem', marginBottom: 6 }}>
                      {HERO_CLASS_ICONS[hero.heroClass] ?? '⚔'}
                    </div>
                    <div style={{ fontFamily: 'var(--font-display)', fontSize: '0.85rem', color: 'var(--text)', marginBottom: 4 }}>
                      {HERO_CLASSES[hero.heroClass] ?? `Class ${hero.heroClass}`}
                    </div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--muted)', marginBottom: 6 }}>
                      Level {hero.level}
                    </div>
                    {/* ID — самое важное для Арены */}
                    <div style={{
                      background: 'rgba(255,180,0,0.1)', border: '1px solid rgba(255,180,0,0.3)',
                      borderRadius: 6, padding: '4px 8px',
                      fontFamily: 'var(--font-display)', fontSize: '0.8rem', color: 'var(--amber)',
                    }}>
                      Token ID: {hero.id}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* ── Классы ── */}
          <div style={cardStyle}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '0.9rem', color: 'var(--muted)', marginBottom: 20, textTransform: 'uppercase', letterSpacing: '0.1em' }}>
              Hero Classes
            </h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 }}>
              {HERO_CLASSES.map((cls, i) => (
                <div key={cls} onClick={() => setSelectedClass(i)} style={{
                  border: `1px solid ${selectedClass === i ? 'var(--amber)' : 'var(--border)'}`,
                  borderRadius: 8, padding: '20px 16px', textAlign: 'center',
                  background: selectedClass === i ? 'rgba(196,127,23,0.08)' : 'rgba(255,255,255,0.02)',
                  cursor: 'pointer', transition: 'border-color 0.15s, background 0.15s',
                }}>
                  <div style={{ fontSize: '2rem', marginBottom: 8 }}>{HERO_CLASS_ICONS[i]}</div>
                  <div style={{ fontFamily: 'var(--font-display)', fontSize: '0.85rem', color: 'var(--text)' }}>{cls}</div>
                </div>
              ))}
            </div>
          </div>

          {/* ── Минт ── */}
          <div style={cardStyle}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '0.9rem', color: 'var(--amber)', marginBottom: 4, textTransform: 'uppercase', letterSpacing: '0.1em' }}>
              🔨 Mint Hero
            </h2>
            <p style={{ color: 'var(--muted)', fontSize: '0.82rem', marginBottom: 20 }}>
              Anyone can mint a hero. You'll receive <span style={{ color: 'var(--amber)' }}>100 AETH</span> starter pack automatically.
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

            <button style={btnStyle(isBusy)} disabled={isBusy} onClick={handleMint}>
              {isBusy ? 'Minting…' : `Mint ${HERO_CLASSES[selectedClass]}`}
            </button>

            {mintStatus === 'success' && (
              <div style={{ marginTop: 12, padding: '10px 14px', borderRadius: 6, background: 'rgba(34,197,94,0.1)', border: '1px solid rgba(34,197,94,0.3)', color: '#4ade80', fontSize: '0.85rem' }}>
                ✅ Hero minted! Check your heroes above.
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
