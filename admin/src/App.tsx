import { useEffect, useMemo, useState, type FormEvent } from 'react'
import type { User } from 'firebase/auth'
import { SettingsPanel } from './components/SettingsPanel'
import { WallpaperForm } from './components/WallpaperForm'
import { WallpaperList } from './components/WallpaperList'
import { FOUR_K_CATEGORY, IOS_CATEGORY, matchesCategory } from './lib/categories'
import {
  isAdminUser,
  listWallpapers,
  loginWithEmail,
  loginWithGoogle,
  logout,
  saveWallpaperOrder,
  watchAuth,
} from './lib/firebase'
import { replaceManifestWallpapers } from './lib/github'
import { withCategoryRankOrder, type WallpaperRecord } from './lib/types'
import './App.css'

type HomeTab = 'home' | 'ios' | 'fourK' | 'upload' | 'settings'

const NAV: { id: HomeTab; label: string; icon: string }[] = [
  { id: 'home', label: 'Dashboard', icon: 'fa-th-large' },
  { id: 'ios', label: 'iOS 27 Wallpapers', icon: 'fa-mobile-screen' },
  { id: 'fourK', label: '4K Wallpapers', icon: 'fa-image' },
  { id: 'settings', label: 'Settings', icon: 'fa-gear' },
]

export default function App() {
  const [user, setUser] = useState<User | null>(null)
  const [authReady, setAuthReady] = useState(false)
  const [email, setEmail] = useState('elbouhssiini@gmail.com')
  const [password, setPassword] = useState('')
  const [items, setItems] = useState<WallpaperRecord[]>([])
  const [loading, setLoading] = useState(false)
  const [bootError, setBootError] = useState<string | null>(null)
  const [busyAuth, setBusyAuth] = useState(false)
  const [tab, setTab] = useState<HomeTab>('home')

  const authed = isAdminUser(user)

  const stats = useMemo(() => {
    const ios = items.filter((item) => matchesCategory(item.category, IOS_CATEGORY.name)).length
    const fourK = items.filter((item) => item.category === FOUR_K_CATEGORY.name).length
    return { ios, fourK, total: ios + fourK }
  }, [items])

  const pageMeta = useMemo(() => {
    switch (tab) {
      case 'home':
        return {
          kicker: 'Library',
          title: 'All Wallpapers',
          subtitle: 'Every wallpaper across iOS 27 Wallpapers and 4K Wallpapers.',
          status: `${stats.total} items`,
        }
      case 'ios':
        return {
          kicker: 'Catalog',
          title: 'iOS 27 Wallpapers',
          subtitle: 'Drag to reorder. Changes save automatically.',
          status: `${stats.ios} items`,
        }
      case 'fourK':
        return {
          kicker: 'Catalog',
          title: '4K Wallpapers',
          subtitle: 'Drag to reorder. Changes save automatically.',
          status: `${stats.fourK} items`,
        }
      case 'upload':
        return {
          kicker: 'Publishing',
          title: 'Upload',
          subtitle: 'Pick a catalog, drop images, publish.',
          status: 'Ready',
        }
      case 'settings':
        return {
          kicker: 'Configuration',
          title: 'Settings',
          subtitle: 'AdMob and app configuration.',
          status: 'Live',
        }
    }
  }, [tab, stats.ios, stats.fourK, stats.total])

  useEffect(() => {
    return watchAuth((next) => {
      setUser(next)
      setAuthReady(true)
      if (next && !isAdminUser(next)) {
        setBootError('This account is not an admin.')
        void logout()
      }
    })
  }, [])

  useEffect(() => {
    if (!authed) return
    let alive = true
    setLoading(true)
    setBootError(null)
    listWallpapers()
      .then((data) => {
        if (alive) setItems(data)
      })
      .catch((err: unknown) => {
        if (alive) {
          setBootError(err instanceof Error ? err.message : 'Could not load wallpapers.')
        }
      })
      .finally(() => {
        if (alive) setLoading(false)
      })
    return () => {
      alive = false
    }
  }, [authed])

  async function reindexAfterUpload(created: WallpaperRecord[]) {
    const createdIds = new Set(created.map((item) => item.id))
    const current = await listWallpapers()
    const rest = current.filter((item) => !createdIds.has(item.id))
    const ranked = withCategoryRankOrder(
      [...created, ...rest],
      [IOS_CATEGORY.name, FOUR_K_CATEGORY.name],
    )
    const saved = await saveWallpaperOrder(ranked)
    await replaceManifestWallpapers(saved)
    setItems(saved)

    setTab('home')
  }

  async function onEmailLogin(event: FormEvent) {
    event.preventDefault()
    setBootError(null)
    setBusyAuth(true)
    try {
      await loginWithEmail(email.trim(), password)
    } catch (err) {
      setBootError(err instanceof Error ? err.message : 'Sign in failed.')
    } finally {
      setBusyAuth(false)
    }
  }

  async function onGoogleLogin() {
    setBootError(null)
    setBusyAuth(true)
    try {
      await loginWithGoogle()
    } catch (err) {
      setBootError(err instanceof Error ? err.message : 'Google sign in failed.')
    } finally {
      setBusyAuth(false)
    }
  }

  if (!authReady) {
    return (
      <div className="shell--gate">
        <p className="banner banner--loading">Checking auth…</p>
      </div>
    )
  }

  if (!authed) {
    return (
      <div className="shell--gate">
        <form className="gate-card" onSubmit={onEmailLogin}>
          <p className="brand-mark">Wallora Glass</p>
          <h1>Admin</h1>
          <p className="lede">Sign in to manage wallpapers.</p>

          <label>
            Email
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="username"
              disabled={busyAuth}
              autoFocus
            />
          </label>

          <label>
            Password
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              disabled={busyAuth}
            />
          </label>

          {bootError ? <p className="banner banner--error">{bootError}</p> : null}

          <button className="primary-btn" type="submit" disabled={busyAuth}>
            {busyAuth ? 'Signing in…' : 'Sign in'}
          </button>

          <div className="gate-divider" aria-hidden="true">
            or
          </div>

          <button
            className="ghost-btn"
            type="button"
            disabled={busyAuth}
            onClick={() => void onGoogleLogin()}
          >
            Continue with Google
          </button>
        </form>
      </div>
    )
  }

  return (
    <div className="container">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <h2>Wallora Glass</h2>
          <div className="sidebar-admin-status">Logged In</div>
        </div>

        <nav aria-label="Main">
          <ul>
            {NAV.map((item) => (
              <li key={item.id}>
                <button
                  type="button"
                  className={`nav-link${tab === item.id ? ' active' : ''}`}
                  onClick={() => setTab(item.id)}
                >
                  <span className="nav-link__label">
                    <i className={`fas ${item.icon}`} aria-hidden="true" />
                    {item.label}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </nav>

        <footer className="sidebar-footer">
          <button
            type="button"
            className="sidebar-logout"
            id="sidebar-logout"
            onClick={() => {
              void logout()
              setItems([])
              setTab('home')
            }}
          >
            <i className="fas fa-sign-out-alt" aria-hidden="true" />
            Logout
          </button>
        </footer>
      </aside>

      <main className="main-content">
        <section className="content-section active">
          <header className="admin-page-header">
            <div className="admin-page-heading">
              <p className="admin-page-kicker">{pageMeta.kicker}</p>
              <h1>{pageMeta.title}</h1>
              <p className="section-subtitle">{pageMeta.subtitle}</p>
            </div>
            <div className="admin-page-actions">
              {tab === 'home' ? (
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => setTab('upload')}
                >
                  <i className="fas fa-cloud-arrow-up" aria-hidden="true" />
                  Upload
                </button>
              ) : null}
              <div className="admin-page-status">{pageMeta.status}</div>
            </div>
          </header>

          {bootError ? <p className="banner banner--error">{bootError}</p> : null}
          {loading ? <p className="banner banner--loading">Loading…</p> : null}

          {tab === 'home' ? (
            <WallpaperList
              items={items}
              onChange={setItems}
              onUploadClick={() => setTab('upload')}
            />
          ) : null}

          {tab === 'ios' ? (
            <WallpaperList
              items={items}
              categoryName={IOS_CATEGORY.name}
              onChange={setItems}
            />
          ) : null}

          {tab === 'fourK' ? (
            <WallpaperList
              items={items}
              categoryName={FOUR_K_CATEGORY.name}
              onChange={setItems}
            />
          ) : null}

          {tab === 'upload' ? (
            <WallpaperForm
              onCreated={(record) => {
                setItems((prev) =>
                  prev.some((item) => item.id === record.id) ? prev : [record, ...prev],
                )
              }}
              onBatchComplete={reindexAfterUpload}
            />
          ) : null}

          {tab === 'settings' ? <SettingsPanel /> : null}
        </section>
      </main>
    </div>
  )
}
