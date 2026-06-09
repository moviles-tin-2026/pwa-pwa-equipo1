import { useMemo, useState } from 'react'
import { useApp } from '../store/AppContext'
import { currency, STATUS_LABEL, stockPercent, stockStatus } from '../store/helpers'
import { IconFilter, IconPlus, IconSearch } from '../components/Icons'
import AddProductModal from '../components/AddProductModal'
import type { StockStatus } from '../data/types'

const FILTERS: { key: StockStatus | 'all'; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'in-stock', label: 'In Stock' },
  { key: 'low-stock', label: 'Low Stock' },
  { key: 'out-of-stock', label: 'Out of Stock' },
]

export default function Inventory() {
  const { products } = useApp()
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState<StockStatus | 'all'>('all')
  const [showFilters, setShowFilters] = useState(false)
  const [showAdd, setShowAdd] = useState(false)

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase()
    return products.filter((p) => {
      const matchesQ =
        !q || p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q)
      const matchesF = filter === 'all' || stockStatus(p) === filter
      return matchesQ && matchesF
    })
  }, [products, query, filter])

  return (
    <div className="page">
      <div className="inv-toolbar">
        <div className="inv-toolbar__search">
          <IconSearch width={18} height={18} />
          <input
            placeholder="Search product name or SKU…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
        <div className="inv-toolbar__actions">
          <button
            className={'btn btn--ghost' + (showFilters ? ' btn--ghost-active' : '')}
            onClick={() => setShowFilters((s) => !s)}
          >
            <IconFilter width={16} height={16} />
            Filters
          </button>
          <button className="btn btn--primary" onClick={() => setShowAdd(true)}>
            <IconPlus width={18} height={18} />
            Add Product
          </button>
        </div>
      </div>

      {showFilters && (
        <div className="chips">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              className={'chip' + (filter === f.key ? ' chip--active' : '')}
              onClick={() => setFilter(f.key)}
            >
              {f.label}
            </button>
          ))}
        </div>
      )}

      {visible.length === 0 ? (
        <p className="empty">No products match your search.</p>
      ) : (
        <div className="product-grid">
          {visible.map((p) => {
            const status = stockStatus(p)
            const pct = stockPercent(p)
            return (
              <article
                key={p.id}
                className={'product-card' + (status === 'low-stock' || status === 'out-of-stock' ? ' product-card--alert' : '')}
              >
                <div className="product-card__media">
                  <img src={p.image} alt={p.name} loading="lazy" />
                  <span className={`badge badge--${status}`}>
                    {STATUS_LABEL[status].toUpperCase()}
                  </span>
                </div>
                <div className="product-card__body">
                  <div className="product-card__title">
                    <h3>{p.name}</h3>
                    <span className="product-card__price">{currency(p.price)}</span>
                  </div>
                  <div className="product-card__sku mono">SKU: {p.sku}</div>
                  <div className="product-card__stock-label">STOCK LEVEL</div>
                  <div className="product-card__stock-row">
                    <span
                      className={
                        'product-card__units' +
                        (status !== 'in-stock' ? ' product-card__units--alert' : '')
                      }
                    >
                      {p.stock} Units
                    </span>
                    <div className="bar">
                      <div className={`bar__fill bar__fill--${status}`} style={{ width: `${pct}%` }} />
                    </div>
                  </div>
                </div>
              </article>
            )
          })}
        </div>
      )}

      {showAdd && <AddProductModal onClose={() => setShowAdd(false)} />}
    </div>
  )
}
