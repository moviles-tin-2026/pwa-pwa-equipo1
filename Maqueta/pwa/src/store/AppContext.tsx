import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { CartItem, Product } from '../data/types'
import { PRODUCTS } from '../data/mockData'

interface AppState {
  // auth
  isAuthenticated: boolean
  userEmail: string
  login: (email: string) => void
  logout: () => void

  // inventory
  products: Product[]
  addProduct: (p: Omit<Product, 'id'>) => void

  // cart / current sale
  cart: CartItem[]
  addToCart: (p: Product) => void
  removeFromCart: (id: string) => void
  changeQty: (id: string, delta: number) => void
  clearCart: () => void
  confirmSale: () => void
}

const AppContext = createContext<AppState | null>(null)

const AUTH_KEY = 'pyme-auth'

export function AppProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem(AUTH_KEY) || 'null') as
        | { email: string }
        | null
    } catch {
      return null
    }
  })
  const [products, setProducts] = useState<Product[]>(PRODUCTS)
  const [cart, setCart] = useState<CartItem[]>([])

  const login = useCallback((email: string) => {
    const next = { email }
    localStorage.setItem(AUTH_KEY, JSON.stringify(next))
    setAuth(next)
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem(AUTH_KEY)
    setAuth(null)
  }, [])

  const addProduct = useCallback((p: Omit<Product, 'id'>) => {
    setProducts((prev) => [{ ...p, id: `p${Date.now()}` }, ...prev])
  }, [])

  const addToCart = useCallback((p: Product) => {
    setCart((prev) => {
      const found = prev.find((i) => i.product.id === p.id)
      if (found) {
        return prev.map((i) =>
          i.product.id === p.id ? { ...i, qty: i.qty + 1 } : i,
        )
      }
      return [...prev, { product: p, qty: 1 }]
    })
  }, [])

  const removeFromCart = useCallback((id: string) => {
    setCart((prev) => prev.filter((i) => i.product.id !== id))
  }, [])

  const changeQty = useCallback((id: string, delta: number) => {
    setCart((prev) =>
      prev
        .map((i) =>
          i.product.id === id ? { ...i, qty: Math.max(0, i.qty + delta) } : i,
        )
        .filter((i) => i.qty > 0),
    )
  }, [])

  const clearCart = useCallback(() => setCart([]), [])

  const confirmSale = useCallback(() => {
    setProducts((prev) =>
      prev.map((p) => {
        const line = cart.find((i) => i.product.id === p.id)
        return line ? { ...p, stock: Math.max(0, p.stock - line.qty) } : p
      }),
    )
    setCart([])
  }, [cart])

  const value = useMemo<AppState>(
    () => ({
      isAuthenticated: !!auth,
      userEmail: auth?.email ?? '',
      login,
      logout,
      products,
      addProduct,
      cart,
      addToCart,
      removeFromCart,
      changeQty,
      clearCart,
      confirmSale,
    }),
    [
      auth,
      login,
      logout,
      products,
      addProduct,
      cart,
      addToCart,
      removeFromCart,
      changeQty,
      clearCart,
      confirmSale,
    ],
  )

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export function useApp() {
  const ctx = useContext(AppContext)
  if (!ctx) throw new Error('useApp must be used within AppProvider')
  return ctx
}
