import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { CartItem, Product, UserProfile } from '../data/types'
import { PRODUCTS, USERS } from '../data/mockData'

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

  // users
  users: UserProfile[]
  toggleUserStatus: (id: string) => void
  cycleUserRole: (id: string) => void
}

const AppContext = createContext<AppState | null>(null)

const AUTH_KEY = 'pyme-auth'

function buildSku(value: string | undefined, existing: Product[]) {
  const trimmed = value?.trim().toUpperCase()
  if (trimmed) {
    const exists = existing.some((item) => item.sku.toUpperCase() === trimmed)
    if (!exists) return trimmed
    const suffix = Date.now().toString().slice(-4)
    return `${trimmed}-${suffix}`
  }

  return `SKU-${Date.now().toString().slice(-6)}`
}

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
  const [users, setUsers] = useState<UserProfile[]>(USERS)

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
    setProducts((prev) => [
      {
        ...p,
        sku: buildSku(p.sku, prev),
        id: `p${Date.now()}`,
      },
      ...prev,
    ])
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

  const toggleUserStatus = useCallback((id: string) => {
    setUsers((prev) =>
      prev.map((u) =>
        u.id === id
          ? { ...u, status: u.status === 'active' ? 'inactive' : 'active' }
          : u,
      ),
    )
  }, [])

  const cycleUserRole = useCallback((id: string) => {
    setUsers((prev) =>
      prev.map((u) => {
        if (u.id !== id) return u
        const roles: UserProfile['role'][] = ['cashier', 'manager', 'admin']
        const currentIndex = roles.indexOf(u.role)
        const nextRole = roles[(currentIndex + 1) % roles.length]
        return { ...u, role: nextRole }
      }),
    )
  }, [])

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
      users,
      toggleUserStatus,
      cycleUserRole,
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
      users,
      toggleUserStatus,
      cycleUserRole,
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
