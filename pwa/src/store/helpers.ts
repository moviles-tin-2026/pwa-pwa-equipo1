import type { Product, StockStatus } from '../data/types'

export function stockStatus(p: Product): StockStatus {
  if (p.stock <= 0) return 'out-of-stock'
  if (p.stock <= 5) return 'low-stock'
  return 'in-stock'
}

export function stockPercent(p: Product): number {
  return Math.max(0, Math.min(100, Math.round((p.stock / p.maxStock) * 100)))
}

export const STATUS_LABEL: Record<StockStatus, string> = {
  'in-stock': 'In Stock',
  'low-stock': 'Low Stock',
  'out-of-stock': 'Out of Stock',
}

export const currency = (n: number) =>
  n.toLocaleString('en-US', { style: 'currency', currency: 'USD' })
