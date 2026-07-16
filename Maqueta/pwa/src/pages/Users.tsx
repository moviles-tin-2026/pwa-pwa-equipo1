import { useMemo } from 'react'
import { useApp } from '../store/AppContext'

const ROLE_LABEL: Record<'admin' | 'manager' | 'cashier', string> = {
  admin: 'Admin',
  manager: 'Manager',
  cashier: 'Cajero',
}

export default function Users() {
  const { users, toggleUserStatus, cycleUserRole } = useApp()

  const stats = useMemo(() => {
    const active = users.filter((u) => u.status === 'active').length
    const admins = users.filter((u) => u.role === 'admin').length
    const pending = users.filter((u) => u.status === 'pending').length

    return { active, admins, pending }
  }, [users])

  return (
    <div className="page">
      <div className="page__head">
        <h1>Usuarios y permisos</h1>
        <p className="page__sub">
          Revisa el estado del equipo, prioriza accesos y mantén la operación más organizada.
        </p>
        <div className="user-summary">
          <span className="user-summary__pill">Activos: {stats.active}</span>
          <span className="user-summary__pill">Admin: {stats.admins}</span>
          <span className="user-summary__pill">Pendientes: {stats.pending}</span>
        </div>
      </div>

      <section className="kpi-grid">
        <article className="kpi-card">
          <span className="kpi-card__label">Usuarios activos</span>
          <strong className="kpi-card__value">{stats.active}</strong>
          <span className="kpi-card__foot">Operando hoy</span>
        </article>
        <article className="kpi-card">
          <span className="kpi-card__label">Administradores</span>
          <strong className="kpi-card__value">{stats.admins}</strong>
          <span className="kpi-card__foot">Con acceso total</span>
        </article>
        <article className="kpi-card kpi-card--alert">
          <span className="kpi-card__label">Pendientes</span>
          <strong className="kpi-card__value">{stats.pending}</strong>
          <span className="kpi-card__foot">Por activar o revisar</span>
        </article>
      </section>

      <section className="panel">
        <div className="panel__head">
          <h2>Equipo de operación</h2>
          <button className="btn btn--ghost">Invitar usuario</button>
        </div>

        <div className="user-grid">
          {users.map((user) => {
            const initials = user.name
              .split(' ')
              .slice(0, 2)
              .map((part) => part[0]?.toUpperCase() ?? '')
              .join('')

            return (
              <article key={user.id} className="user-card">
                <div className="user-card__top">
                  <div className="user-card__avatar">{initials}</div>
                  <div className="user-card__info">
                    <h3>{user.name}</h3>
                    <p>{user.email}</p>
                  </div>
                  <span className={`pill pill--${user.role}`}>{ROLE_LABEL[user.role]}</span>
                </div>

                <div className="user-card__meta">
                  <span>{user.focus}</span>
                  <span>{user.lastActive}</span>
                </div>

                <div className="user-card__footer">
                  <button className="btn btn--ghost" onClick={() => toggleUserStatus(user.id)}>
                    {user.status === 'active' ? 'Desactivar' : 'Activar'}
                  </button>
                  <button className="btn btn--primary" onClick={() => cycleUserRole(user.id)}>
                    Cambiar rol
                  </button>
                </div>
              </article>
            )
          })}
        </div>
      </section>
    </div>
  )
}
