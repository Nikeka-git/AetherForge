import { useWriteContract, usePublicClient } from 'wagmi'
import { parseGwei } from 'viem'

/**
 * Drop-in замена useWriteContract.
 * Оборачивает и writeContractAsync, и writeContract —
 * перед каждой транзакцией читает реальный baseFee и
 * передаёт maxFeePerGas = baseFee * 2, обходя оценку MetaMask.
 */
export function useGasWrite() {
  const { writeContractAsync, writeContract: _writeContract, ...rest } = useWriteContract()
  const client = usePublicClient()

  async function fetchGasOverride() {
    try {
      const block = await client.getBlock({ blockTag: 'latest' })
      if (block.baseFeePerGas) {
        return {
          maxFeePerGas:         block.baseFeePerGas * 2n + parseGwei('0.001'),
          maxPriorityFeePerGas: parseGwei('0.001'),
        }
      }
    } catch {}
    return {
      maxFeePerGas:         parseGwei('0.5'),
      maxPriorityFeePerGas: parseGwei('0.001'),
    }
  }

  async function writeContractAsyncWithGas(params) {
    const gas = await fetchGasOverride()
    return writeContractAsync({ ...params, ...gas })
  }

  // writeContract — fire-and-forget, но gas всё равно нужен
  // запускаем async получение gas и вызываем через writeContractAsync
  function writeContractWithGas(params) {
    fetchGasOverride().then(gas => {
      writeContractAsync({ ...params, ...gas }).catch(() => {})
    })
  }

  return {
    writeContractAsync: writeContractAsyncWithGas,
    writeContract:      writeContractWithGas,
    ...rest,
  }
}