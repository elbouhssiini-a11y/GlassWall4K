import { useCallback, useEffect, useMemo, useState } from 'react'
import { Toast, useToast } from './Toast'
import { usePageStatus, type PageStatus } from './StatusBadge'
import { getGithubAssetConfig } from '../lib/github'
import { loadAppSettings } from '../lib/firebase'
import { IOS_CATEGORY, LIVE_CATEGORY, matchesCategory } from '../lib/categories'
import { DEFAULT_APP_SETTINGS, type AppSettings, type WallpaperRecord } from '../lib/types'

type WorkspaceTab = 'home' | 'ios' | 'live' | 'upload' | 'intro' | 'settings' | 'ads'

const RULES = [
  'iOS 27 Wallpapers accept image files only',
  'Live Wallpapers accept video files only',
  'Intro accepts video files only',
  'Uploads publish automatically to the catalog',
] as const

type Props = {
  items?: WallpaperRecord[]
  onNavigate?: (tab: WorkspaceTab) => void
  onStatusChange?: (status: PageStatus | null) => void
}

export function ConfigPanel({ items = [], onNavigate, onStatusChange }: Props) {
  const github = getGithubAssetConfig()
  const [checking, setChecking] = useState(true)
  const [settings, setSettings] = useState<AppSettings>({ ...DEFAULT_APP_SETTINGS })
  const [settingsError, setSettingsError] = useState<string | null>(null)
  const { toast, show, clear } = useToast()

  const iosCount = useMemo(
    () => items.filter((item) => matchesCategory(item.category, IOS_CATEGORY.name)).length,
    [items],
  )
  const liveCount = useMemo(
    () => items.filter((item) => matchesCategory(item.category, LIVE_CATEGORY.name)).length,
    [items],
  )
  const featuredCount = useMemo(() => items.filter((item) => item.featured).length, [items])

  const iosThumbs = useMemo(
    () =>
      items
        .filter((item) => matchesCategory(item.category, IOS_CATEGORY.name))
        .slice(0, 4)
        .map((item) => item.thumbnailURL),
    [items],
  )
  const liveThumbs = useMemo(
    () =>
      items
        .filter((item) => matchesCategory(item.category, LIVE_CATEGORY.name))
        .slice(0, 4)
        .map((item) => item.thumbnailURL),
    [items],
  )

  const refresh = useCallback(async () => {
    setChecking(true)
    setSettingsError(null)
    try {
      const data = await loadAppSettings()
      setSettings(data)
      setSettingsError(null)
      return true
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Could not load app settings.'
      setSettingsError(message)
      setSettings({ ...DEFAULT_APP_SETTINGS })
      throw err
    } finally {
      setChecking(false)
    }
  }, [])

  useEffect(() => {
    void refresh().catch(() => {
      /* initial load errors surface via status badge */
    })
  }, [refresh])

  async function handleRefresh() {
    clear()
    show('Refreshing workspace…', 'loading')
    try {
      await refresh()
      show('Workspace refreshed.')
    } catch (err: unknown) {
      show(err instanceof Error ? err.message : 'Could not refresh workspace.', 'error')
    }
  }

  async function copyValue(label: string, value: string) {
    if (!value || value === '—') {
      show(`${label} is empty.`, 'error')
      return
    }
    clear()
    try {
      await navigator.clipboard.writeText(value)
      show(`Copied ${label}.`)
    } catch {
      show(`Could not copy ${label}.`, 'error')
    }
  }

  const status = useMemo<PageStatus>(() => {
    if (checking) return { tone: 'busy', label: 'Checking…', title: 'Loading workspace status' }
    if (settingsError) return { tone: 'off', label: 'Settings load failed', title: settingsError }
    if (!github.ok) {
      return {
        tone: 'off',
        label: 'Configuration Incomplete',
        title: `Missing: ${github.issues.join(', ')}`,
      }
    }
    return { tone: 'ok', label: 'Workspace Ready', title: 'GitHub env and settings are reachable' }
  }, [checking, settingsError, github.ok, github.issues])

  usePageStatus(status, onStatusChange)

  const collections = [
    {
      label: 'iOS 27 Wallpapers',
      value: IOS_CATEGORY.name,
      note: 'Catalog category',
      count: iosCount,
    },
    {
      label: 'Live Wallpapers',
      value: LIVE_CATEGORY.name,
      note: 'Catalog category',
      count: liveCount,
    },
    {
      label: 'Intro',
      value: 'settings / intro-assets',
      note: 'App settings + GitHub Release',
      count: null as number | null,
    },
  ]

  const githubRows = [
    { label: 'Repository', value: github.repository },
    { label: 'Branch', value: github.branch },
    { label: 'Images Folder', value: github.imagesFolder },
    { label: 'Videos Folder', value: `${github.videosFolder} (same as images)` },
    { label: 'Intro Release', value: github.introRelease },
  ]

  const quickLinks = [
    {
      id: 'ios' as const,
      title: 'iOS 27 Wallpapers',
      desc: 'Images · drag to reorder',
      icon: 'fa-mobile-screen',
      count: iosCount,
      thumbs: iosThumbs,
    },
    {
      id: 'live' as const,
      title: 'Live Wallpapers',
      desc: 'Videos · drag to reorder',
      icon: 'fa-play-circle',
      count: liveCount,
      thumbs: liveThumbs,
    },
    {
      id: 'intro' as const,
      title: 'Intro',
      desc: settings.introEnabled ? 'Enabled · publish to app' : 'Disabled',
      icon: 'fa-clapperboard',
      count: null,
      thumbs: settings.introImageURL ? [settings.introImageURL] : [],
    },
    {
      id: 'ads' as const,
      title: 'Ads Management',
      desc: settings.adsEnabled
        ? `${settings.adsMode === 'test' ? 'Test' : 'Production'} mode`
        : 'Disabled',
      icon: 'fa-chart-line',
      count: null,
      thumbs: [],
    },
  ]

  return (
    <div className="cfg-panel">
      {checking ? <Toast message="Checking workspace…" variant="loading" /> : null}
      {toast ? <Toast message={toast.message} variant={toast.variant} /> : null}

      <div className="cfg-panel__toolbar">
        <p>
          Workspace overview · GitHub env from <code>.env.local</code> · remote app settings from
          Firestore
        </p>
        <button
          type="button"
          className="intro-stage__publish"
          disabled={checking}
          onClick={() => void handleRefresh()}
        >
          <i className={`fas ${checking ? 'fa-spinner fa-spin' : 'fa-rotate'}`} aria-hidden="true" />
          Refresh
        </button>
      </div>

      <section className="cfg-card cfg-card--status">
        <header className="cfg-card__head">
          <h2>Workspace Status</h2>
          <p>Live snapshot of catalogs, remote settings and GitHub.</p>
        </header>
        <div className="cfg-status-grid">
          <div className="cfg-status-item">
            <span>GitHub</span>
            <em className={github.ok ? 'is-on' : 'is-off'}>{github.ok ? 'OK' : 'OFF'}</em>
          </div>
          <div className="cfg-status-item">
            <span>iOS items</span>
            <em className="is-on">{iosCount}</em>
          </div>
          <div className="cfg-status-item">
            <span>Live items</span>
            <em className="is-on">{liveCount}</em>
          </div>
          <div className="cfg-status-item">
            <span>Featured</span>
            <em className={featuredCount > 0 ? 'is-on' : 'is-off'}>{featuredCount}</em>
          </div>
          <div className="cfg-status-item">
            <span>Intro</span>
            <em className={settings.introEnabled ? 'is-on' : 'is-off'}>
              {settings.introEnabled ? 'ON' : 'OFF'}
            </em>
          </div>
          <div className="cfg-status-item">
            <span>Ads</span>
            <em className={settings.adsEnabled ? 'is-on' : 'is-off'}>
              {settings.adsEnabled ? 'ON' : 'OFF'}
            </em>
          </div>
        </div>
      </section>

      <div className="cfg-panel__stage">
        <section className="cfg-card cfg-card--quick">
          <header className="cfg-card__head">
            <h2>Quick Links</h2>
            <p>Jump to the main workspace pages.</p>
          </header>
          <div className="cfg-quick-grid">
            {quickLinks.map((link) => (
              <button
                key={link.id}
                type="button"
                className="cfg-quick-card"
                onClick={() => onNavigate?.(link.id)}
              >
                <div className="cfg-quick-card__head">
                  <span className="cfg-quick-card__icon" aria-hidden="true">
                    <i className={`fas ${link.icon}`} />
                  </span>
                  <div>
                    <strong>{link.title}</strong>
                    <em>{link.desc}</em>
                  </div>
                  {link.count !== null ? (
                    <span className="cfg-quick-card__count">{link.count}</span>
                  ) : null}
                </div>
                <div className="dash-thumbs">
                  {link.thumbs.length > 0 ? (
                    link.thumbs.map((src) => <img key={src} src={src} alt="" loading="lazy" />)
                  ) : (
                    <span className="dash-thumbs__empty">No preview yet</span>
                  )}
                </div>
              </button>
            ))}
          </div>
        </section>

        <section className="cfg-card cfg-card--remote">
          <header className="cfg-card__head">
            <h2>Remote App Settings</h2>
            <p>What the iOS app reads from Firestore / GitHub mirror.</p>
          </header>
          <ul className="cfg-rows">
            <li className="cfg-row">
              <span>
                Intro title
                <em className="cfg-row__note">{settings.introSubtitle || 'No subtitle'}</em>
              </span>
              <code>{settings.introTitle}</code>
            </li>
            <li className="cfg-row">
              <span>Intro version</span>
              <code>v{settings.introVersion}</code>
            </li>
            <li className="cfg-row">
              <span>Intro playback</span>
              <code>
                {settings.introEnabled
                  ? settings.introMaxSeconds > 0
                    ? `${settings.introMaxSeconds}s max`
                    : 'Full length'
                  : 'Off'}
              </code>
            </li>
            <li className="cfg-row">
              <span>Ads mode</span>
              <code>{settings.adsEnabled ? settings.adsMode : 'off'}</code>
            </li>
            <li className="cfg-row">
              <span>App open delay</span>
              <code>{settings.appOpenMinBackgroundSeconds}s</code>
            </li>
          </ul>
          <div className="cfg-card__actions">
            <button type="button" className="panel-link-btn" onClick={() => onNavigate?.('intro')}>
              Edit Intro
            </button>
            <button type="button" className="panel-link-btn" onClick={() => onNavigate?.('ads')}>
              Edit Ads
            </button>
            <button type="button" className="panel-link-btn" onClick={() => onNavigate?.('home')}>
              All Wallpapers
            </button>
          </div>
        </section>
      </div>

      <div className="cfg-panel__grid">
        <section className="cfg-card">
          <header className="cfg-card__head">
            <h2>Content Collections</h2>
            <p>Catalog categories in Firestore, plus intro media settings.</p>
          </header>
          <ul className="cfg-rows">
            {collections.map((row) => (
              <li key={row.label} className="cfg-row">
                <span>
                  {row.label}
                  <em className="cfg-row__note">
                    {row.note}
                    {row.count !== null ? ` · ${row.count} items` : ''}
                  </em>
                </span>
                <code>{row.value}</code>
              </li>
            ))}
          </ul>
        </section>

        <section className="cfg-card">
          <header className="cfg-card__head">
            <h2>GitHub Assets</h2>
            <p>Where wallpapers, videos and intro media are stored.</p>
          </header>
          <ul className="cfg-rows">
            {githubRows.map((row) => (
              <li key={row.label} className="cfg-row cfg-row--action">
                <span>{row.label}</span>
                <div className="cfg-row__value">
                  <code>{row.value}</code>
                  <button
                    type="button"
                    className="cfg-copy"
                    onClick={() =>
                      void copyValue(row.label, row.value.replace(/ \(same as images\)$/, ''))
                    }
                    aria-label={`Copy ${row.label}`}
                    title="Copy"
                  >
                    <i className="fas fa-copy" aria-hidden="true" />
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </section>

        <section className="cfg-card">
          <header className="cfg-card__head">
            <h2>Rules</h2>
            <p>Upload and visibility rules for each content type.</p>
          </header>
          <ul className="cfg-rules">
            {RULES.map((rule) => (
              <li key={rule} className="cfg-rule">
                <i className="fas fa-check" aria-hidden="true" />
                <span>{rule}</span>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <p className="cfg-panel__note">
        Repo / branch / token come from <code>admin/.env.local</code>. Restart Vite after changing
        env. Intro and Ads save automatically and publish to <code>settings.json</code>.
      </p>
    </div>
  )
}
