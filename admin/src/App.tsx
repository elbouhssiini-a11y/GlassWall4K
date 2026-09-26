import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import type { User } from 'firebase/auth'
import { ConfigPanel } from './components/ConfigPanel'
import { IntroPanel } from './components/IntroPanel'
import { SettingsPanel } from './components/SettingsPanel'
import { StatusBadge, type PageStatus } from './components/StatusBadge'
import { Toast } from './components/Toast'
import { WallpaperForm } from './components/WallpaperForm'
import { WallpaperList } from './components/WallpaperList'
import { LIVE_CATEGORY, IOS_CATEGORY, isIosCategory, isLiveCategory } from './lib/categories'
import {
  isAdminUser,
  listWallpapers,
  loginWithEmail,
  loginWithGoogle,
  logout,
  removeWallpapers,
  saveWallpaperOrder,
  watchAuth,
} from './lib/firebase'
import { replaceManifestWallpapers } from './lib/github'
import { withCategoryRankOrder, needsCategoryRankFix, type WallpaperRecord } from './lib/types'
import './App.css'

type HomeTab = 'home' | 'ios' | 'live' | 'upload' | 'intro' | 'settings' | 'ads'

const NAV: { id: Exclude<HomeTab, 'upload'>; label: string; icon: string }[] = [
  { id: 'home', label: 'Dashboard', icon: 'fa-th-large' },
  { id: 'ios', label: 'iOS 27 Wallpapers', icon: 'fa-mobile-screen' },
  { id: 'live', label: 'Live Wallpapers', icon: 'fa-play-circle' },
  { id: 'intro', label: 'Intro', icon: 'fa-clapperboard' },
  { id: 'settings', label: 'Settings', icon: 'fa-gear' },
  { id: 'ads', label: 'Ads Management', icon: 'fa-chart-line' },
]

function navActiveId(tab: HomeTab, uploadCategory: string): Exclude<HomeTab, 'upload'> {
  if (tab !== 'upload') return tab
  return uploadCategory === LIVE_CATEGORY.name ? 'live' : 'ios'
}

export default function App() {
  const [user, setUser] = useState<User | null>(null)
  const [authReady, setAuthReady] = useState(false)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [items, setItems] = useState<WallpaperRecord[]>([])
  const [loading, setLoading] = useState(false)
  const [bootError, setBootError] = useState<string | null>(null)
  const [busyAuth, setBusyAuth] = useState(false)
  const [tab, setTab] = useState<HomeTab>('home')
  const [uploadCategory, setUploadCategory] = useState(IOS_CATEGORY.name)
  const [pageStatus, setPageStatus] = useState<PageStatus | null>(null)

  const authed = isAdminUser(user)
  const activeNav = navActiveId(tab, uploadCategory)
  const onPageStatusChange = useCallback((status: PageStatus | null) => {
    setPageStatus(status)
  }, [])

  useEffect(() => {
    setPageStatus(null)
  }, [tab])

  function openUpload(categoryName = IOS_CATEGORY.name) {
    setUploadCategory(categoryName)
    setTab('upload')
  }

  const pageMeta = useMemo(() => {
    switch (tab) {
      case 'home':
        return {
          kicker: 'Library',
          title: 'All Wallpapers',
          subtitle: 'Browse, search and filter every wallpaper across iOS 27 and Live catalogs.',
        }
      case 'ios':
        return {
          kicker: 'Catalog',
          title: 'iOS 27 Wallpapers',
          subtitle: 'Drag to reorder. Changes save automatically.',
        }
      case 'live':
        return {
          kicker: 'Catalog',
          title: 'Live Wallpapers',
          subtitle: 'Drag to reorder. Changes save automatically.',
        }
      case 'upload':
        return {
          kicker: 'Publishing',
          title: 'Upload',
          subtitle: 'Pick a catalog, drop images or videos, publish.',
        }
      case 'intro':
        return {
          kicker: 'Onboarding',
          title: 'Intro',
          subtitle: 'Fullscreen launch video · duration · publish to the iOS app.',
        }
      case 'settings':
        return {
          kicker: 'Workspace',
          title: 'Settings',
          subtitle: 'Workspace status, content collections, GitHub assets and upload rules.',
        }
      case 'ads':
        return {
          kicker: 'Remote configuration',
          title: 'Ads Management',
          subtitle: 'Manage App Open and Interstitial ads remotely.',
        }
    }
  }, [tab])

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
      .then(async (data) => {
        if (!alive) return
        const categoryNames = [IOS_CATEGORY.name, LIVE_CATEGORY.name]

        // Drop wallpapers that are neither iOS 27 nor Live (legacy orphans).
        const orphans = data.filter(
          (item) => !isIosCategory(item.category) && !isLiveCategory(item.category),
        )
        let kept = data
        if (orphans.length > 0) {
          await removeWallpapers(orphans.map((item) => item.id))
          kept = data.filter(
            (item) => isIosCategory(item.category) || isLiveCategory(item.category),
          )
        }

        const ranked = needsCategoryRankFix(kept, categoryNames)
          ? withCategoryRankOrder(
              [...kept].sort((a, b) => {
                if (a.sortOrder !== b.sortOrder) return a.sortOrder - b.sortOrder
                return b.createdAt.localeCompare(a.createdAt)
              }),
              categoryNames,
            )
          : kept

        const changed =
          orphans.length > 0 || needsCategoryRankFix(kept, categoryNames)
        if (!changed) {
          setItems(kept)
          return
        }

        try {
          const saved = await saveWallpaperOrder(ranked)
          await replaceManifestWallpapers(saved)
          if (alive) setItems(saved)
        } catch {
          if (alive) setItems(ranked)
        }
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
      [IOS_CATEGORY.name, LIVE_CATEGORY.name],
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
        <Toast message="Checking auth…" variant="loading" />
      </div>
    )
  }

  if (!authed) {
    return (
      <div className="shell--gate">
        <form className="gate-card" onSubmit={onEmailLogin}>
          <div className="gate-brand">
            <img className="app-icon" src="/app-icon.png" alt="" />
            <p className="brand-mark">Wallora Glass</p>
          </div>
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

          {bootError ? <Toast message={bootError} variant="error" /> : null}

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
          <img className="app-icon" src="/app-icon.png" alt="" />
          <div>
            <h2>Wallora Glass</h2>
            <div className="sidebar-admin-status">Logged In</div>
          </div>
        </div>

        <nav aria-label="Main">
          <ul>
            {NAV.map((item) => (
              <li key={item.id}>
                <button
                  type="button"
                  className={`nav-link${activeNav === item.id ? ' active' : ''}`}
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
        <section className="content-section">
          <header className="admin-page-header">
            <div className="admin-page-heading">
              <p className="admin-page-kicker">{pageMeta.kicker}</p>
              <h1>{pageMeta.title}</h1>
              <p className="section-subtitle">{pageMeta.subtitle}</p>
            </div>
            <div className="admin-page-actions">
              {tab === 'home' ? (
                <div className="page-stat" role="status">
                  <span className="page-stat__label">Total items</span>
                  <strong className="page-stat__value">{items.length}</strong>
                </div>
              ) : null}
              {pageStatus ? (
                <StatusBadge
                  tone={pageStatus.tone}
                  label={pageStatus.label}
                  title={pageStatus.title}
                />
              ) : null}
              {tab === 'home' ? (
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => openUpload(IOS_CATEGORY.name)}
                >
                  <i className="fas fa-cloud-arrow-up" aria-hidden="true" />
                  Upload
                </button>
              ) : null}
              {tab === 'ios' ? (
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => openUpload(IOS_CATEGORY.name)}
                >
                  <i className="fas fa-cloud-arrow-up" aria-hidden="true" />
                  Upload
                </button>
              ) : null}
              {tab === 'live' ? (
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => openUpload(LIVE_CATEGORY.name)}
                >
                  <i className="fas fa-film" aria-hidden="true" />
                  Upload video
                </button>
              ) : null}
            </div>
          </header>

          {bootError ? <Toast message={bootError} variant="error" /> : null}
          {loading ? <Toast message="Loading…" variant="loading" /> : null}

          {tab === 'home' ? (
            <WallpaperList
              items={items}
              onChange={setItems}
              onUploadClick={() => openUpload(IOS_CATEGORY.name)}
            />
          ) : null}

          {tab === 'ios' ? (
            <WallpaperList
              items={items}
              categoryName={IOS_CATEGORY.name}
              onChange={setItems}
              onUploadClick={() => openUpload(IOS_CATEGORY.name)}
            />
          ) : null}

          {tab === 'live' ? (
            <WallpaperList
              items={items}
              categoryName={LIVE_CATEGORY.name}
              onChange={setItems}
              onUploadClick={() => openUpload(LIVE_CATEGORY.name)}
            />
          ) : null}

          {tab === 'upload' ? (
            <WallpaperForm
              key={uploadCategory}
              initialCategory={uploadCategory}
              onCreated={(record) => {
                setItems((prev) =>
                  prev.some((item) => item.id === record.id) ? prev : [record, ...prev],
                )
              }}
              onBatchComplete={reindexAfterUpload}
            />
          ) : null}

          {tab === 'intro' ? <IntroPanel onStatusChange={onPageStatusChange} /> : null}

          {tab === 'settings' ? (
            <ConfigPanel
              items={items}
              onNavigate={setTab}
              onStatusChange={onPageStatusChange}
            />
          ) : null}

          {tab === 'ads' ? <SettingsPanel onStatusChange={onPageStatusChange} /> : null}
        </section>
      </main>
    </div>
  )
}
