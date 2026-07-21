import { useMemo, useState } from 'react'
import AddProductModal from '../components/AddProductModal'
import { useApp } from '../store/AppContext'
import { currency, STATUS_LABEL, stockStatus } from '../store/helpers'
import {
  IconCart,
  IconCheck,
  IconFilter,
  IconGrid,
  IconPlus,
  IconReceipt,
  IconSearch,
  IconTrash,
} from '../components/Icons'

const TAX_RATE = 0.08

export default function Transactions() {
  const { products, cart, addToCart, changeQty, removeFromCart, clearCart, confirmSale } = useApp()
  const [done, setDone] = useState(false)
  const [query, setQuery] = useState('')
  const [showAddProduct, setShowAddProduct] = useState(false)

  const subtotal = useMemo(
    () => cart.reduce((sum, i) => sum + i.product.price * i.qty, 0),
    [cart],
  )
  const tax = subtotal * TAX_RATE
  const total = subtotal + tax

  const handleConfirm = () => {
    if (cart.length === 0) return
    confirmSale()
    setDone(true)
    setTimeout(() => setDone(false), 2200)
  }

  const filteredProducts = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return products

    return products.filter((p) => {
      const haystack = [p.name, p.sku, p.category, p.description]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
      return haystack.includes(q)
    })
  }, [products, query])

  const getProductCode = (product: { sku?: string; code?: string }) => product.sku || product.code || 'Sin código'

  return (
    <div className="page sale">
      <section className="sale__catalog">
        <div className="sale__catalog-head">
          <div>
            <h1>Terminal de ventas</h1>
            <p className="page__sub">Selecciona productos, ajusta cantidades y finaliza la venta con una vista más clara.</p>
            <div className="sale__meta">
              <span className="sale__meta-pill">Productos: {products.length}</span>
              <span className="sale__meta-pill">Ticket: {currency(subtotal)}</span>
            </div>
          </div>
          <div className="sale__view-toggle">
            <button className="icon-btn icon-btn--bordered" aria-label="Filter">
              <IconFilter width={18} height={18} />
            </button>
            <button className="icon-btn icon-btn--bordered" aria-label="Grid view">
              <IconGrid width={18} height={18} />
            </button>
          </div>
        </div>

        <label className="sale__search">
          <IconSearch width={16} height={16} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Buscar por nombre, código o SKU"
          />
        </label>

        {filteredProducts.length === 0 ? (
          <div className="sale__empty sale__empty--compact">
            <p>No hay productos con ese código o nombre.</p>
            <button className="btn btn--ghost" type="button" onClick={() => setShowAddProduct(true)}>
              Agregar producto
            </button>
          </div>
        ) : (
          <div className="catalog-grid">
            {filteredProducts.map((p) => {
              const status = stockStatus(p)
              return (
                <button
                  key={p.id}
                  className="catalog-card"
                  onClick={() => addToCart(p)}
                  disabled={status === 'out-of-stock'}
                >
                <div className="catalog-card__head">
                  <span className={`badge badge--${status}`}>{STATUS_LABEL[status]}</span>
                  <span className="catalog-card__sku mono">{getProductCode(p)}</span>
                </div>
                <div className="catalog-card__media">
                  <img src={p.image} alt={p.name} loading="lazy" />
                </div>
                <h3 className="catalog-card__name">{p.name}</h3>
                <p className="catalog-card__desc">{p.description}</p>
                <div className="catalog-card__code mono">Código: {getProductCode(p)}</div>
                <div className="catalog-card__price">{currency(p.price)}</div>
              </button>
            )
          })}
          </div>
        )}
      </section>

      <aside className="sale__panel">
        <div className="sale__panel-head">
          <div>
            <h2>Venta actual</h2>
            <p className="panel__sub">Resumen rápido del ticket</p>
          </div>
          <button
            className="icon-btn"
            aria-label="Clear sale"
            onClick={clearCart}
            disabled={cart.length === 0}
          >
            <IconReceipt width={20} height={20} />
          </button>
        </div>

        <div className="sale__items">
          {cart.length === 0 ? (
            <div className="sale__empty">
              <IconCart width={48} height={48} />
              <p>Select items to start a sale</p>
            </div>
          ) : (
            cart.map((i) => (
              <div key={i.product.id} className="sale-line">
                <img src={i.product.image} alt="" className="sale-line__img" />
                <div className="sale-line__info">
                  <div className="sale-line__name">{i.product.name}</div>
                  <div className="sale-line__price mono">{currency(i.product.price)}</div>
                  <div className="sale-line__code mono">{getProductCode(i.product)}</div>
                </div>
                <div className="sale-line__qty">
                  <button onClick={() => changeQty(i.product.id, -1)} aria-label="Decrease">−</button>
                  <span>{i.qty}</span>
                  <button onClick={() => changeQty(i.product.id, 1)} aria-label="Increase">
                    <IconPlus width={14} height={14} />
                  </button>
                </div>
                <button
                  className="sale-line__remove"
                  onClick={() => removeFromCart(i.product.id)}
                  aria-label="Remove"
                >
                  <IconTrash width={16} height={16} />
                </button>
              </div>
            ))
          )}
        </div>

        <div className="sale__summary">
          <div className="sale__row">
            <span>Subtotal</span>
            <span className="mono">{currency(subtotal)}</span>
          </div>
          <div className="sale__row">
            <span>Tax (8%)</span>
            <span className="mono">{currency(tax)}</span>
          </div>
          <div className="sale__row sale__row--total">
            <span>Total</span>
            <span className="mono">{currency(total)}</span>
          </div>
          <button
            className="btn btn--primary btn--block btn--lg"
            onClick={handleConfirm}
            disabled={cart.length === 0}
          >
            <IconCheck width={20} height={20} />
            {done ? 'SALE CONFIRMED' : 'CONFIRM SALE'}
          </button>
        </div>
      </aside>

      {showAddProduct && (
        <AddProductModal
          onClose={() => setShowAddProduct(false)}
          initialName={query.trim()}
          initialSku={query.trim()}
        />
      )}
    </div>
  )
}
