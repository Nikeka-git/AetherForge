import { useAccount, useReadContract, useReadContracts } from 'wagmi'
import { formatEther } from 'viem'
import { useState, useEffect } from 'react'
import { ADDRESSES, AETH_ABI, TREASURY_ABI } from '../lib/contracts.js'
import { fetchRecentSwaps } from '../lib/subgraph.js'

function StatCard({ label, value, sub, icon }) {
  return (
    <div style={{
      background: 'var(--surface)',
      border: '1px solid var(--border)',
      borderRadius: 10,
      padding: '20px 24px',
    }}>
      <div style={{ fontSize: '1.4rem', marginBottom: 8 }}>{icon}</div>
      <div style={{ fontSize: '0.72rem', color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 4 }}>
        {label}
      </div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: '1.4rem', color: 'var(--amber)', fontWeight: 700 }}>
        {value}
      </div>
      {sub && <div style={{ fontSize: '0.78rem', color: 'var(--muted)', marginTop: 4 }}>{sub}</div>}
    </div>
  )
}

export default function Dashboard() {
  const { address, isConnected } = useAccount()
  const [swaps, setSwaps] = useState([])
  const [swapsLoading, setSwapsLoading] = useState(true)
  const [swapsError, setSwapsError] = useState(null)

  const { data } = useReadContracts({
    contracts: [
      { address: ADDRESSES.AethToken, abi: AETH_ABI, functionName: 'balanceOf', args: [address] },
      { address: ADDRESSES.AethToken, abi: AETH_ABI, functionName: 'getVotes', args: [address] },
      { address: ADDRESSES.AethToken, abi: AETH_ABI, functionName: 'delegates', args: [address] },
      { address: ADDRESSES.AethToken, abi: AETH_ABI, functionName: 'totalSupply' },
      { address: ADDRESSES.GuildTreasury, abi: TREASURY_ABI, functionName: 'balanceOf', args: [address] },
      { address: ADDRESSES.GuildTreasury, abi: TREASURY_ABI, functionName: 'totalAssets' },
    ],
    query: { enabled: isConnected && !!address },
  })

  const [aethBal, votes, delegate, totalSupply, vaultShares, totalAssets] = data?.map(d => d.result) ?? []

  useEffect(() => {
    fetchRecentSwaps(10)
      .then(setSwaps)
      .catch(e => setSwapsError(e.message))
      .finally(() => setSwapsLoading(false))
  }, [])

  const fmt = (v) => v !== undefined ? parseFloat(formatEther(v)).toLocaleString('en-US', { maximumFractionDigits: 2 }) : '—'
  const shortAddr = (a) => a ? `${a.slice(0, 6)}…${a.slice(-4)}` : '—'

  return (
    <div style={{ maxWidth: 1140, margin: '0 auto', padding: '32px 24px' }}>
      <h1 style={{ fontFamily: 'var(--font-display)', color: 'var(--amber)', marginBottom: 8, fontSize: '1.4rem' }}>
        ◈ Protocol Overview
      </h1>
      <p style={{ color: 'var(--muted)', marginBottom: 32, fontSize: '0.88rem' }}>
        Your AetherForge Arena dashboard
      </p>

      {!isConnected ? (
        <div style={{
          background: 'var(--surface)', border: '1px solid var(--border)',
          borderRadius: 10, padding: '40px', textAlign: 'center', color: 'var(--muted)',
        }}>
          Connect your wallet to view your stats
        </div>
      ) : (
        <>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 16, marginBottom: 40 }}>
            <StatCard icon="⚡" label="AETH Balance"    value={fmt(aethBal)}    sub="governance token" />
            <StatCard icon="🗳️" label="Voting Power"   value={fmt(votes)}       sub="delegated votes" />
            <StatCard icon="👤" label="Delegate"        value={shortAddr(delegate)} sub="current delegate" />
            <StatCard icon="🏦" label="Vault Shares"    value={fmt(vaultShares)} sub="gETH shares held" />
            <StatCard icon="💰" label="Vault Assets"    value={fmt(totalAssets)} sub="total AETH in vault" />
            <StatCard icon="🪙" label="Total Supply"   value={fmt(totalSupply)} sub="AETH total supply" />
          </div>

          {/* Subgraph section */}
          <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: 24 }}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '1rem', color: 'var(--amber)', marginBottom: 20 }}>
              Recent Swaps  <span style={{ fontSize: '0.7rem', color: 'var(--muted)', fontFamily: 'var(--font-body)', fontWeight: 400 }}>via The Graph</span>
            </h2>

            {swapsLoading && <p style={{ color: 'var(--muted)', fontSize: '0.88rem' }}>Loading from subgraph…</p>}
            {swapsError && <p style={{ color: '#e05', fontSize: '0.88rem' }}>Subgraph error: {swapsError}</p>}

            {!swapsLoading && !swapsError && swaps.length === 0 && (
              <p style={{ color: 'var(--muted)', fontSize: '0.88rem' }}>No recent swaps found.</p>
            )}

            {swaps.length > 0 && (
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.83rem' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border)' }}>
                    {['User', 'Token In', 'Amount In', 'Token Out', 'Amount Out', 'Time'].map(h => (
                      <th key={h} style={{ padding: '8px 12px', textAlign: 'left', color: 'var(--muted)', fontWeight: 500, fontSize: '0.72rem', textTransform: 'uppercase', letterSpacing: '0.07em' }}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {swaps.map(s => (
                    <tr key={s.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                      <td style={{ padding: '10px 12px', color: 'var(--text)' }}>{shortAddr(s.user)}</td>
                      <td style={{ padding: '10px 12px', color: 'var(--muted)' }}>{shortAddr(s.tokenIn)}</td>
                      <td style={{ padding: '10px 12px', color: 'var(--amber)' }}>{parseFloat(formatEther(BigInt(s.amountIn || 0))).toFixed(4)}</td>
                      <td style={{ padding: '10px 12px', color: 'var(--muted)' }}>{shortAddr(s.tokenOut)}</td>
                      <td style={{ padding: '10px 12px', color: 'var(--amber)' }}>{parseFloat(formatEther(BigInt(s.amountOut || 0))).toFixed(4)}</td>
                      <td style={{ padding: '10px 12px', color: 'var(--muted)' }}>
                        {new Date(Number(s.timestamp) * 1000).toLocaleTimeString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}
    </div>
  )
}
