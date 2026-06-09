export type StockStatus = 'in-stock' | 'low-stock' | 'out-of-stock'

export interface Product {
  id: string
  name: string
  sku: string
  price: number
  stock: number
  /** Stock level at which the bar is considered "full" (100%). */
  maxStock: number
  category: string
  description: string
  image: string
}

export type TransactionStatus = 'completed' | 'pending' | 'refunded'

export interface Transaction {
  id: string
  product: string
  status: TransactionStatus
  amount: number
}

export interface CartItem {
  product: Product
  qty: number
}
