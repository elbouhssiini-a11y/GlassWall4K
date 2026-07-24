import { useEffect, useRef, useState } from 'react'
import { Toast, useToast } from './Toast'
import { loadAppSettings, saveAppSettings } from '../lib/firebase'
import {
  DEFAULT_APP_SETTINGS,
  IOS_TEST_AD_UNITS,
  resolveAdUnitIds,
  type AppSettings,
} from '../lib/types'

export function SettingsPanel() {
  const [settings, setSettings] = useState<AppSettings>({ ...DEFAULT_APP_SETTINGS })
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
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
    loadAppSettings()
      .then((data) => {
        if (alive) {
          setSettings(data)
          latestRef.current = data
          readyRef.current = true
        }
      })
      .catch((err: unknown) => {
        if (alive) {
          const message = err instanceof Error ? err.message : 'Could not load settings.'
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
      if (saveTimerRef.current) clearTimeout(saveTimerRef.current)
    }
  }, [])

  async function persist(next: AppSettings) {
    setBusy(true)
    clear()
    show('Saving…', 'loading')
    try {
      const saved = await saveAppSettings(next)
      setSettings(saved)
      latestRef.current = saved
      show('Saved.')
    } catch (err) {
      show(err instanceof Error ? err.message : 'Could not save settings.', 'error')
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

  return (
    <div className="settings-layout">
      {loading ? <Toast message="Loading settings…" variant="loading" /> : null}
      {toast ? <Toast message={toast.message} variant={toast.variant} /> : null}

      <div className="panel-grid">
        <div className="panel-col">
          <div className="panel-card">
            <div className="panel-card-head">
              <h3>Ads</h3>
              <p>App Open + Interstitial · Test or Production</p>
            </div>
            <ul className="panel-list">
              <li>
                <span>Ads enabled</span>
                <label className="panel-switch">
                  <input
                    type="checkbox"
                    checked={settings.adsEnabled}
                    disabled={loading || busy}
                    onChange={(e) => patch({ adsEnabled: e.target.checked }, true)}
                  />
                  <code className="panel-badge">{settings.adsEnabled ? 'On' : 'Off'}</code>
                </label>
              </li>
              <li>
                <span>Mode</span>
                <div className="ads-mode-toggle">
                  <button
                    type="button"
                    className={`ads-mode-btn${isTest ? ' ads-mode-btn--on' : ''}`}
                    disabled={loading || busy}
                    onClick={() => patch({ adsMode: 'test' }, true)}
                  >
                    Test
                  </button>
                  <button
                    type="button"
                    className={`ads-mode-btn${!isTest ? ' ads-mode-btn--on' : ''}`}
                    disabled={loading || busy}
                    onClick={() => patch({ adsMode: 'production' }, true)}
                  >
                    Production
                  </button>
                </div>
              </li>
              <li>
                <span>Interstitial every N opens</span>
                <input
                  className="panel-inline-input"
                  type="number"
                  min={1}
                  max={50}
                  value={settings.interstitialEveryNOpens}
                  disabled={loading || busy}
                  onChange={(e) =>
                    patch({ interstitialEveryNOpens: Number(e.target.value) || 1 }, true)
                  }
                />
              </li>
              <li>
                <span>Interstitial every N downloads</span>
                <input
                  className="panel-inline-input"
                  type="number"
                  min={1}
                  max={50}
                  value={settings.interstitialEveryNDownloads}
                  disabled={loading || busy}
                  onChange={(e) =>
                    patch(
                      {
                        interstitialEveryNDownloads: Number(e.target.value) || 1,
                      },
                      true,
                    )
                  }
                />
              </li>
            </ul>
          </div>

          <div className="panel-card">
            <div className="panel-card-head">
              <h3>Active in app</h3>
              <p>
                {isTest
                  ? 'Google demo units (safe). App shows Test ads.'
                  : 'Your production units. App shows live ads.'}
              </p>
            </div>
            <ul className="panel-list">
              <li>
                <span>App Open</span>
                <code className="panel-badge">{activeIds.appOpenAdUnitId || '—'}</code>
              </li>
              <li>
                <span>Interstitial</span>
                <code className="panel-badge">{activeIds.interstitialAdUnitId || '—'}</code>
              </li>
            </ul>
          </div>
        </div>

        <div className="panel-col">
          <div className="panel-card">
            <div className="panel-card-head">
              <h3>Production AdMob IDs</h3>
              <p>
                {isTest
                  ? `Saved for later. Test mode uses ${IOS_TEST_AD_UNITS.appOpen.split('/')[0]}…`
                  : 'Used now while mode is Production'}
              </p>
            </div>
            <ul className="panel-list panel-list--stack">
              <li className="panel-list__stack-row">
                <span>App Open</span>
                <input
                  value={settings.appOpenAdUnitId}
                  disabled={loading || busy}
                  placeholder="ca-app-pub-xxxx/yyyy"
                  onChange={(e) => patch({ appOpenAdUnitId: e.target.value })}
                />
              </li>
              <li className="panel-list__stack-row">
                <span>Interstitial</span>
                <input
                  value={settings.interstitialAdUnitId}
                  disabled={loading || busy}
                  placeholder="ca-app-pub-xxxx/yyyy"
                  onChange={(e) => patch({ interstitialAdUnitId: e.target.value })}
                />
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}
