import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext'
import {
  IconArrowRight,
  IconCloud,
  IconEye,
  IconEyeOff,
  IconInventory,
  IconLock,
  IconShield,
} from '../components/Icons'

export default function Login() {
  const { login } = useApp()
  const navigate = useNavigate()
  const [email, setEmail] = useState('owner@business.com')
  const [password, setPassword] = useState('password')
  const [show, setShow] = useState(false)
  const [remember, setRemember] = useState(false)

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!email || !password) return
    login(email)
    navigate('/dashboard')
  }

  return (
    <div className="login">
      <div className="login__inner">
        <header className="login__head">
          <div className="login__logo" aria-hidden>
            <IconInventory width={34} height={34} />
          </div>
          <h1 className="login__brand">PyME-Sync</h1>
          <p className="login__tag">Professional Inventory Control</p>
        </header>

        <form className="login__card" onSubmit={submit}>
          <h2>Welcome Back</h2>
          <p className="login__muted">Please enter your details to sign in</p>

          <label className="field">
            <span className="field__label">Email Address</span>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              required
            />
          </label>

          <label className="field">
            <span className="field__row">
              <span className="field__label">Password</span>
              <a className="field__link" href="#forgot" onClick={(e) => e.preventDefault()}>
                Forgot Password?
              </a>
            </span>
            <span className="field__input-wrap">
              <input
                type={show ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                required
              />
              <button
                type="button"
                className="field__toggle"
                onClick={() => setShow((s) => !s)}
                aria-label={show ? 'Hide password' : 'Show password'}
              >
                {show ? <IconEyeOff width={18} height={18} /> : <IconEye width={18} height={18} />}
              </button>
            </span>
          </label>

          <label className="checkbox">
            <input
              type="checkbox"
              checked={remember}
              onChange={(e) => setRemember(e.target.checked)}
            />
            <span>Keep me logged in for 30 days</span>
          </label>

          <button type="submit" className="btn btn--primary btn--block btn--lg">
            SIGN IN
            <IconArrowRight width={18} height={18} />
          </button>

          <div className="login__divider" />

          <p className="login__signup">
            New to PyME-Sync? <a href="#request" onClick={(e) => e.preventDefault()}>Request an Account</a>
          </p>
        </form>

        <footer className="login__badges">
          <span><IconShield width={16} height={16} /> Secure SSL</span>
          <span><IconLock width={16} height={16} /> GDPR Compliant</span>
          <span><IconCloud width={16} height={16} /> Auto Backup</span>
        </footer>
      </div>
    </div>
  )
}
