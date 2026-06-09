import { useApp } from '../store/AppContext'
import { IconCloud, IconLock, IconLogout, IconShield } from '../components/Icons'

export default function Settings() {
  const { userEmail, logout } = useApp()

  return (
    <div className="page">
      <div className="page__head">
        <h1>Settings</h1>
        <p className="page__sub">Manage your account and workspace preferences.</p>
      </div>

      <div className="settings-grid">
        <article className="panel">
          <h2 className="panel__title">Account</h2>
          <div className="settings-row">
            <span>Email</span>
            <span className="mono">{userEmail || 'owner@business.com'}</span>
          </div>
          <div className="settings-row">
            <span>Role</span>
            <span className="pill pill--completed">ADMIN</span>
          </div>
          <div className="settings-row">
            <span>Workspace</span>
            <span>PyME-Sync</span>
          </div>
          <button className="btn btn--ghost btn--block" onClick={logout}>
            <IconLogout width={16} height={16} />
            Sign out
          </button>
        </article>

        <article className="panel">
          <h2 className="panel__title">Preferences</h2>
          <Toggle label="Low stock alerts" defaultOn />
          <Toggle label="Email notifications" defaultOn />
          <Toggle label="Dark mode" />
          <Toggle label="Auto backup" defaultOn />
        </article>

        <article className="panel settings-grid__full">
          <h2 className="panel__title">Security & Compliance</h2>
          <div className="settings-badges">
            <span className="settings-badge"><IconShield width={18} height={18} /> Secure SSL</span>
            <span className="settings-badge"><IconLock width={18} height={18} /> GDPR Compliant</span>
            <span className="settings-badge"><IconCloud width={18} height={18} /> Auto Backup</span>
          </div>
        </article>
      </div>
    </div>
  )
}

function Toggle({ label, defaultOn = false }: { label: string; defaultOn?: boolean }) {
  return (
    <label className="toggle">
      <span>{label}</span>
      <span className="toggle__switch">
        <input type="checkbox" defaultChecked={defaultOn} />
        <span className="toggle__slider" />
      </span>
    </label>
  )
}
