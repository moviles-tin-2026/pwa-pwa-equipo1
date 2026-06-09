import { DASHBOARD_STATS, TRANSACTIONS } from '../data/mockData'
import { currency } from '../store/helpers'
import {
  IconAlert,
  IconCash,
  IconReceipt,
  IconStar,
  IconTrend,
} from '../components/Icons'
import type { TransactionStatus } from '../data/types'

const STATUS_TEXT: Record<TransactionStatus, string> = {
  completed: 'COMPLETED',
  pending: 'PENDING',
  refunded: 'REFUNDED',
}

export default function Dashboard() {
  const s = DASHBOARD_STATS
  return (
    <div className="page">
      <div className="page__head">
        <h1>Overview</h1>
        <p className="page__sub">Here is what is happening with your stock today.</p>
      </div>

      <section className="stat-grid">
        <article className="stat-card">
          <div className="stat-card__top">
            <span className="stat-card__label">TOTAL SALES TODAY</span>
            <span className="stat-card__icon"><IconCash width={20} height={20} /></span>
          </div>
          <div className="stat-card__value">{currency(s.totalSales)}</div>
          <div className="stat-card__delta stat-card__delta--up">
            <IconTrend width={14} height={14} /> {s.salesDelta}% vs yesterday
          </div>
        </article>

        <article className="stat-card">
          <div className="stat-card__top">
            <span className="stat-card__label">TRANSACTIONS COUNT</span>
            <span className="stat-card__icon"><IconReceipt width={20} height={20} /></span>
          </div>
          <div className="stat-card__value">{s.transactionsCount}</div>
          <div className="stat-card__foot">Completed today</div>
        </article>

        <article className="stat-card stat-card--alert">
          <div className="stat-card__top">
            <span className="stat-card__label">LOW STOCK ITEMS</span>
            <span className="stat-card__icon stat-card__icon--alert">
              <IconAlert width={20} height={20} />
            </span>
          </div>
          <div className="stat-card__value stat-card__value--alert">
            {String(s.lowStockItems).padStart(2, '0')}
          </div>
          <div className="stat-card__foot stat-card__foot--alert">Action required immediately</div>
        </article>

        <article className="stat-card stat-card--feature">
          <div className="stat-card__top">
            <span className="stat-card__label stat-card__label--inverse">TOP SELLING PRODUCT</span>
            <span className="stat-card__icon stat-card__icon--inverse">
              <IconStar width={20} height={20} />
            </span>
          </div>
          <div className="stat-card__product">{s.topProduct.name}</div>
          <div className="stat-card__foot stat-card__foot--inverse">
            {s.topProduct.units} units this month
          </div>
        </article>
      </section>

      <section className="dash-grid">
        <article className="panel">
          <div className="panel__head">
            <h2>Recent Activity</h2>
            <a className="panel__link" href="#all" onClick={(e) => e.preventDefault()}>View All</a>
          </div>
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>TRANSACTION ID</th>
                  <th>PRODUCT</th>
                  <th>STATUS</th>
                  <th className="num">AMOUNT</th>
                </tr>
              </thead>
              <tbody>
                {TRANSACTIONS.map((t) => (
                  <tr key={t.id}>
                    <td className="mono">#{t.id}</td>
                    <td>{t.product}</td>
                    <td>
                      <span className={`pill pill--${t.status}`}>{STATUS_TEXT[t.status]}</span>
                    </td>
                    <td className="num">{currency(t.amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </article>

        <div className="dash-grid__aside">
          <article className="panel">
            <h2 className="panel__title">Stock Level Distribution</h2>
            <Distribution label="Optimal" value={s.distribution.optimal} variant="optimal" />
            <Distribution label="Low Stock" value={s.distribution.low} variant="low" />
            <Distribution label="Out of Stock" value={s.distribution.out} variant="out" />
          </article>

          <article className="audit">
            <h2>Need an audit?</h2>
            <p>Our consultants can help you optimize your supply chain in 48 hours.</p>
            <button className="btn btn--dark">Book Now</button>
          </article>
        </div>
      </section>
    </div>
  )
}

function Distribution({
  label,
  value,
  variant,
}: {
  label: string
  value: number
  variant: 'optimal' | 'low' | 'out'
}) {
  return (
    <div className="dist">
      <div className="dist__row">
        <span>{label}</span>
        <span>{value}%</span>
      </div>
      <div className="dist__track">
        <div className={`dist__fill dist__fill--${variant}`} style={{ width: `${value}%` }} />
      </div>
    </div>
  )
}
