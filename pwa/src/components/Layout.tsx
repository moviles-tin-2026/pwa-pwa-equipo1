import { NavLink, useLocation, useNavigate } from 'react-router-dom'
import type { ReactNode } from 'react'
import {
  IconBell,
  IconDashboard,
  IconInventory,
  IconLogout,
  IconPlus,
  IconSearch,
  IconSettings,
  IconTransactions,
} from './Icons'
import { useApp } from '../store/AppContext'

const NAV = [
  { to: '/dashboard', label: 'Dashboard', Icon: IconDashboard },
  { to: '/inventory', label: 'Inventory', Icon: IconInventory },
  { to: '/transactions', label: 'Transactions', Icon: IconTransactions },
  { to: '/settings', label: 'Settings', Icon: IconSettings },
]

export default function Layout({ children }: { children: ReactNode }) {
  const { logout, userEmail } = useApp()
  const navigate = useNavigate()
  const location = useLocation()
  const current = NAV.find((n) => location.pathname.startsWith(n.to))

  return (
    <div className="app-shell">
      {/* ===== Sidebar (desktop) ===== */}
      <aside className="sidebar">
        <div className="brand">
          <div className="brand__logo" aria-hidden>
            <IconInventory width={22} height={22} />
          </div>
          <div>
            <div className="brand__name">PyME-Sync</div>
            <div className="brand__sub">Inventory Control</div>
          </div>
        </div>

        <nav className="sidebar__nav">
          {NAV.map(({ to, label, Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                'nav-item' + (isActive ? ' nav-item--active' : '')
              }
            >
              <Icon width={20} height={20} />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="sidebar__footer">
          <button className="btn btn--primary btn--block" onClick={() => navigate('/transactions')}>
            <IconPlus width={18} height={18} />
            Record Sale
          </button>
          <button className="sidebar__logout" onClick={logout}>
            <IconLogout width={16} height={16} />
            Sign out
          </button>
        </div>
      </aside>

      {/* ===== Main column ===== */}
      <div className="main">
        <header className="topbar">
          <div className="topbar__search">
            <IconSearch width={18} height={18} />
            <input placeholder="Search inventory…" aria-label="Search inventory" />
          </div>
          <div className="topbar__right">
            <span className="topbar__role">Admin</span>
            <button className="icon-btn" aria-label="Notifications">
              <IconBell width={20} height={20} />
              <span className="icon-btn__dot" />
            </button>
            <div className="avatar" title={userEmail}>
              {(userEmail[0] || 'A').toUpperCase()}
            </div>
          </div>
        </header>

        <main className="content">{children}</main>
      </div>

      {/* ===== Bottom nav (mobile) ===== */}
      <nav className="bottom-nav" aria-label="Primary">
        {NAV.map(({ to, label, Icon }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              'bottom-nav__item' + (isActive ? ' bottom-nav__item--active' : '')
            }
          >
            <Icon width={22} height={22} />
            <span>{label}</span>
          </NavLink>
        ))}
      </nav>

      {/* ===== Mobile FAB ===== */}
      {current?.to !== '/transactions' && (
        <button
          className="fab"
          aria-label="Record sale"
          onClick={() => navigate('/transactions')}
        >
          <IconPlus width={26} height={26} />
        </button>
      )}
    </div>
  )
}
