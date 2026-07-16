import { useState } from 'react'
import { useApp } from '../store/AppContext'
import { IconPlus } from './Icons'

const DEFAULT_IMG =
  'https://images.unsplash.com/photo-1553413077-190dd305871c?auto=format&fit=crop&w=500&q=60'

export default function AddProductModal({
  onClose,
  initialName = '',
  initialSku = '',
}: {
  onClose: () => void
  initialName?: string
  initialSku?: string
}) {
  const { addProduct } = useApp()
  const [name, setName] = useState(initialName)
  const [sku, setSku] = useState(initialSku)
  const [price, setPrice] = useState('')
  const [stock, setStock] = useState('')
  const [category, setCategory] = useState('')

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    const stockN = Number(stock) || 0
    addProduct({
      name: name.trim() || 'Untitled product',
      sku: sku.trim() || 'SKU-NEW',
      price: Number(price) || 0,
      stock: stockN,
      maxStock: Math.max(stockN, 50),
      category: category.trim() || 'General',
      description: category.trim() || 'General',
      image: DEFAULT_IMG,
    })
    onClose()
  }

  return (
    <div className="modal" role="dialog" aria-modal="true" onClick={onClose}>
      <div className="modal__card" onClick={(e) => e.stopPropagation()}>
        <div className="modal__head">
          <h2>Add Product</h2>
          <button className="modal__close" onClick={onClose} aria-label="Close">×</button>
        </div>
        <form className="modal__body" onSubmit={submit}>
          <label className="field">
            <span className="field__label">Product Name</span>
            <input value={name} onChange={(e) => setName(e.target.value)} required />
          </label>
          <label className="field">
            <span className="field__label">SKU o código</span>
            <input value={sku} onChange={(e) => setSku(e.target.value)} placeholder="Ej. SKU-0001" />
          </label>
          <div className="field-row">
            <label className="field">
              <span className="field__label">Price (USD)</span>
              <input
                type="number"
                min="0"
                step="0.01"
                value={price}
                onChange={(e) => setPrice(e.target.value)}
              />
            </label>
            <label className="field">
              <span className="field__label">Stock</span>
              <input
                type="number"
                min="0"
                value={stock}
                onChange={(e) => setStock(e.target.value)}
              />
            </label>
          </div>
          <label className="field">
            <span className="field__label">Category</span>
            <input value={category} onChange={(e) => setCategory(e.target.value)} />
          </label>
          <div className="modal__actions">
            <button type="button" className="btn btn--ghost" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn--primary">
              <IconPlus width={18} height={18} />
              Add Product
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
