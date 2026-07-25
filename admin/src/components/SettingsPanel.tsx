import { useEffect, useMemo, useRef, useState } from 'react'
import { Toast, useToast } from './Toast'
import { usePageStatus, type PageStatus } from './StatusBadge'
import { loadAppSettings, saveAppSettings } from '../lib/firebase'
import { getGithubAssetConfig } from '../lib/github'
import {
  DEFAULT_APP_SETTINGS,
  resolveAdUnitIds,
  type AppSettings,
} from '../lib/types'

type Props = {
  onStatusChange?: (status: PageStatus | null) => void
}

export function SettingsPanel({ onStatusChange }: Props) {
  const [settings, setSettings] = useState<AppSettings>({ ...DEFAULT_APP_SETTINGS })
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [saveError, setSaveError] = useState<string | null>(null)
  const readyRef = useRef(false)
  const saveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const latestRef = useRef(settings)
  const { toast, show, clear } = useToast()

  useEffect(() => {
    latestRef.current = settings
  }, [settings])

  useEffect(() => {
    let alive = true
    setLoading(true)
    setLoadError(null)
    loadAppSettings()
      .then((data) => {
        if (alive) {
          setSettings(data)
          latestRef.current = data
          readyRef.current = true
          setLoadError(null)
        }
      })
      .catch((err: unknown) => {
        if (alive) {
          const message = err instanceof Error ? err.message : 'Could not load settings.'
          setLoadError(message)
          if (/permission|insufficient/i.test(message)) {
            show(
              'Publish Firestore rules for settings (admin/firestore.rules), then refresh.',
              'error',
            )
          } else {
            show(message, 'error')
          }
          setSettings({ ...DEFAULT_APP_SETTINGS })
          readyRef.current = true
        }
      })
      .finally(() => {
        if (alive) setLoading(false)
      })
    return () => {
      alive = false
      if (saveTimerRef.current) {
        clearTimeout(saveTimerRef.current)
        saveTimerRef.current = null
        if (readyRef.current) {
          void saveAppSettings(latestRef.current).catch(() => {
            /* best-effort flush on leave */
          })
        }
      }
    }
  }, [])

  async function persist(next: AppSettings) {
    setBusy(true)
    clear()
    setSaveError(null)
    show('Saving…', 'loading')
    try {
      const saved = await saveAppSettings(next)
      setSettings(saved)
      latestRef.current = saved
      setSaveError(null)
      show('Saved.')
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Could not save settings.'
      setSaveError(message)
      show(message, 'error')
    } finally {
      setBusy(false)
    }
  }

  function scheduleSave(next: AppSettings, immediate = false) {
    if (!readyRef.current || loading) return
    latestRef.current = next
    setSettings(next)
    if (saveTimerRef.current) clearTimeout(saveTimerRef.current)
    if (immediate) {
      void persist(next)
      return
    }
    saveTimerRef.current = setTimeout(() => {
      void persist(latestRef.current)
    }, 450)
  }

  function patch(partial: Partial<AppSettings>, immediate = false) {
    scheduleSave({ ...latestRef.current, ...partial }, immediate)
  }

  const isTest = settings.adsMode === 'test'
  const activeIds = resolveAdUnitIds(settings)
  const disabled = loading || busy
  const github = getGithubAssetConfig()
  const appOpenOn = settings.adsEnabled && Boolean(activeIds.appOpenAdUnitId)
  const interstitialOn = settings.adsEnabled && Boolean(activeIds.interstitialAdUnitId)

  const badge = useMemo<PageStatus>(() => {
    if (loading) return { tone: 'busy', label: 'Loading', title: 'Loading ads settings' }
    if (busy) return { tone: 'busy', label: 'Saving…', title: 'Saving ads settings' }
    if (loadError) return { tone: 'off', label: 'Load failed', title: loadError }
    if (saveError) return { tone: 'off', label: 'Save failed', title: saveError }
    if (!github.ok) {
      return {
        tone: 'off',
        label: 'Configuration Incomplete',
        title: `Missing: ${github.issues.join(', ')}`,
      }
    }
    return { tone: 'ok', label: 'Synced', title: 'Ads settings are synced' }
  }, [loading, busy, loadError, saveError, github.ok, github.issues])

  usePageStatus(badge, onStatusChange)

  return (
    <div className="ads-mgmt">
      {loading ? <Toast message="Loading settings…" variant="loading" /> : null}
      {toast ? <Toast message={toast.message} variant={toast.variant} /> : null}

      <section className="ads-mgmt__card ads-mgmt__card--status">
        <header className="ads-mgmt__card-head">
          <h2>Ads Status</h2>
          <p>Live overview of the main ad switches. Read-only.</p>
        </header>
        <div className="ads-mgmt__status-grid">
          <div className="ads-mgmt__status-item">
            <span>Ads Enabled</span>
            <em className={settings.adsEnabled ? 'is-on' : 'is-off'}>
              {settings.adsEnabled ? 'ON' : 'OFF'}
            </em>
          </div>
          <div className="ads-mgmt__status-item">
            <span>App Open</span>
            <em className={appOpenOn ? 'is-on' : 'is-off'}>{appOpenOn ? 'ON' : 'OFF'}</em>
          </div>
          <div className="ads-mgmt__status-item">
            <span>Interstitial</span>
            <em className={interstitialOn ? 'is-on' : 'is-off'}>
              {interstitialOn ? 'ON' : 'OFF'}
            </em>
          </div>
          <div className="ads-mgmt__status-item">
            <span>Mode</span>
            <em className="is-on">{isTest ? 'TEST' : 'LIVE'}</em>
          </div>
        </div>
      </section>

      <div className="ads-mgmt__grid">
        <section className="ads-mgmt__card">
          <header className="ads-mgmt__card-head">
            <h2>General</h2>
            <p>Master switch for all ad formats.</p>
          </header>

          <div className="ads-mgmt__body">
            <div className="ads-mgmt__row">
              <div>
                <strong>Ads Enabled</strong>
              </div>
              <label
                className={`ads-mgmt__toggle${settings.adsEnabled ? ' ads-mgmt__toggle--on' : ''}`}
              >
                <input
                  type="checkbox"
                  checked={settings.adsEnabled}
                  disabled={disabled}
                  aria-checked={settings.adsEnabled}
                  onChange={(e) => patch({ adsEnabled: e.target.checked }, true)}
                />
                <i aria-hidden="true" />
              </label>
            </div>

            <div className="ads-mgmt__row">
              <div>
                <strong>Environment</strong>
                <span>Test uses Google demo units.</span>
              </div>
              <div className="ads-mgmt__seg" role="group" aria-label="Ads mode">
                <button
                  type="button"
                  className={isTest ? 'is-on' : undefined}
                  disabled={disabled}
                  onClick={() => patch({ adsMode: 'test' }, true)}
                >
                  Test
                </button>
                <button
                  type="button"
                  className={!isTest ? 'is-on' : undefined}
                  disabled={disabled}
                  onClick={() => patch({ adsMode: 'production' }, true)}
                >
                  Production
                </button>
              </div>
            </div>
          </div>
        </section>

        <section className="ads-mgmt__card">
          <header className="ads-mgmt__card-head">
            <h2>App Open</h2>
            <p>Cold start and return-from-background ads.</p>
          </header>

          <div className="ads-mgmt__body">
            <div className="ads-mgmt__row">
              <div>
                <strong>Background Delay</strong>
                <span>Seconds away before showing again.</span>
              </div>
              <div className="ads-mgmt__num">
                <input
                  type="number"
                  min={0}
                  max={600}
                  value={settings.appOpenMinBackgroundSeconds}
                  disabled={disabled}
                  onChange={(e) =>
                    patch(
                      {
                        appOpenMinBackgroundSeconds: Math.max(0, Number(e.target.value) || 0),
                      },
                      true,
                    )
                  }
                />
                <em>seconds</em>
              </div>
            </div>
          </div>
        </section>

        <section className="ads-mgmt__card">
          <header className="ads-mgmt__card-head">
            <h2>Interstitial</h2>
            <p>Full-screen ads after wallpaper swipes and downloads.</p>
          </header>

          <div className="ads-mgmt__body">
            <div className="ads-mgmt__row">
              <div>
                <strong>Every N swipes</strong>
                <span>Detail swipes before an interstitial.</span>
              </div>
              <div className="ads-mgmt__num">
                <input
                  type="number"
                  min={1}
                  max={50}
                  value={settings.interstitialEveryNOpens}
                  disabled={disabled}
                  onChange={(e) =>
                    patch({ interstitialEveryNOpens: Number(e.target.value) || 1 }, true)
                  }
                />
                <em>swipes</em>
              </div>
            </div>

            <div className="ads-mgmt__row">
              <div>
                <strong>Every N downloads</strong>
                <span>Successful downloads before an interstitial.</span>
              </div>
              <div className="ads-mgmt__num">
                <input
                  type="number"
                  min={1}
                  max={50}
                  value={settings.interstitialEveryNDownloads}
                  disabled={disabled}
                  onChange={(e) =>
                    patch({ interstitialEveryNDownloads: Number(e.target.value) || 1 }, true)
                  }
                />
                <em>downloads</em>
              </div>
            </div>
          </div>
        </section>

        <section className="ads-mgmt__card">
          <header className="ads-mgmt__card-head">
            <h2>Ad Units</h2>
            <p>Production AdMob IDs. Used only in Production mode.</p>
          </header>

          <div className="ads-mgmt__body">
            <label className="ads-mgmt__field">
              <span>App Open unit ID</span>
              <input
                value={settings.appOpenAdUnitId}
                disabled={disabled}
                placeholder="ca-app-pub-…/…"
                spellCheck={false}
                onChange={(e) => patch({ appOpenAdUnitId: e.target.value })}
              />
            </label>

            <label className="ads-mgmt__field">
              <span>Interstitial unit ID</span>
              <input
                value={settings.interstitialAdUnitId}
                disabled={disabled}
                placeholder="ca-app-pub-…/…"
                spellCheck={false}
                onChange={(e) => patch({ interstitialAdUnitId: e.target.value })}
              />
            </label>
          </div>
        </section>
      </div>
    </div>
  )
}
