import { useEffect, useMemo, useRef, useState, type ChangeEvent, type DragEvent } from 'react'
import { Toast, useToast } from './Toast'
import { usePageStatus, type PageStatus } from './StatusBadge'
import { loadAppSettings, saveAppSettings } from '../lib/firebase'
import { getGithubAssetConfig, uploadIntroVideo } from '../lib/github'
import { DEFAULT_APP_SETTINGS, type AppSettings } from '../lib/types'

const DURATION_PRESETS = [
  { label: 'Full', value: 0 },
  { label: '3s', value: 3 },
  { label: '5s', value: 5 },
  { label: '8s', value: 8 },
  { label: '12s', value: 12 },
] as const

type Props = {
  onStatusChange?: (status: PageStatus | null) => void
}

export function IntroPanel({ onStatusChange }: Props) {
  const [settings, setSettings] = useState<AppSettings>({ ...DEFAULT_APP_SETTINGS })
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [dragging, setDragging] = useState(false)
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
          const message = err instanceof Error ? err.message : 'Could not load intro settings.'
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
          void saveAppSettings(latestRef.current, { mirror: true }).catch(() => {
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
    // Always mirror to GitHub — iOS often reads settings.json when Firestore REST is rate-limited.
    show('Saving + publishing to app…', 'loading')
    try {
      const saved = await saveAppSettings(next, { mirror: true })
      setSettings(saved)
      latestRef.current = saved
      setSaveError(null)
      show('Saved + published to app.')
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Could not save intro.'
      setSaveError(message)
      show(message, 'error')
    } finally {
      setBusy(false)
    }
  }

  async function publishToApp() {
    if (disabled) return
    await persist(latestRef.current)
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
    }, 900)
  }

  function patch(partial: Partial<AppSettings>, immediate = false) {
    scheduleSave({ ...latestRef.current, ...partial }, immediate)
  }

  function isVideoFile(file: File) {
    const name = file.name.toLowerCase()
    return (
      file.type.startsWith('video/') ||
      name.endsWith('.mp4') ||
      name.endsWith('.mov') ||
      name.endsWith('.m4v')
    )
  }

  const disabled = loading || busy || uploading

  async function handleVideo(file: File | undefined) {
    if (!file || uploading || disabled) return
    if (!isVideoFile(file)) {
      show('Drop an MP4 or MOV video for the intro.', 'error')
      return
    }

    setUploading(true)
    clear()
    show('Uploading intro video to GitHub…', 'loading')
    try {
      const uploaded = await uploadIntroVideo(file)
      scheduleSave(
        {
          ...latestRef.current,
          introVideoURL: uploaded.videoURL,
          introImageURL: uploaded.imageURL,
        },
        true,
      )
      show('Intro video uploaded and saved.')
    } catch (err) {
      show(err instanceof Error ? err.message : 'Intro video upload failed.', 'error')
    } finally {
      setUploading(false)
    }
  }

  function onDrop(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault()
    setDragging(false)
    void handleVideo(event.dataTransfer.files?.[0])
  }

  function onPick(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    event.target.value = ''
    void handleVideo(file)
  }

  function clearVideo() {
    scheduleSave({ ...latestRef.current, introVideoURL: '', introImageURL: '' }, true)
  }

  const hasVideo = Boolean(settings.introVideoURL)
  const hasPoster = Boolean(settings.introImageURL)
  const github = getGithubAssetConfig()
  const durationLabel =
    settings.introMaxSeconds > 0 ? `${settings.introMaxSeconds}s max` : 'Full length'
  const shortUrl = settings.introVideoURL
    ? settings.introVideoURL.replace(/^https?:\/\//, '').slice(0, 54) +
      (settings.introVideoURL.length > 54 ? '…' : '')
    : ''

  const badge = useMemo<PageStatus>(() => {
    if (loading) return { tone: 'busy', label: 'Loading', title: 'Loading intro settings' }
    if (uploading) return { tone: 'busy', label: 'Uploading…', title: 'Uploading intro video' }
    if (busy) return { tone: 'busy', label: 'Saving…', title: 'Publishing intro settings' }
    if (loadError) return { tone: 'off', label: 'Load failed', title: loadError }
    if (saveError) return { tone: 'off', label: 'Save failed', title: saveError }
    if (!github.ok) {
      return {
        tone: 'off',
        label: 'Configuration Incomplete',
        title: `Missing: ${github.issues.join(', ')}`,
      }
    }
    return { tone: 'ok', label: 'Synced', title: 'Intro settings are synced' }
  }, [loading, uploading, busy, loadError, saveError, github.ok, github.issues])

  usePageStatus(badge, onStatusChange)

  return (
    <div className="intro-stage">
      {loading ? <Toast message="Loading intro…" variant="loading" /> : null}
      {toast ? <Toast message={toast.message} variant={toast.variant} /> : null}

      <div className="intro-stage__toolbar">
        <p>
          Preview left · controls right · tap skips in the app
        </p>
        <button
          type="button"
          className="intro-stage__publish intro-stage__publish--solid"
          disabled={disabled}
          onClick={() => void publishToApp()}
        >
          <i className="fas fa-cloud-arrow-up" aria-hidden="true" />
          Publish to app
        </button>
      </div>

      <div className="intro-stage__layout">
        <div className="intro-stage__preview-wrap">
          <div
            className={`intro-phone${settings.introEnabled ? ' intro-phone--live' : ''}`}
            aria-label="Intro live preview"
          >
            <div className="intro-phone__bezel">
              <div className="intro-phone__notch" aria-hidden="true" />
              <div className="intro-phone__screen intro-phone__screen--fullscreen">
                <div className="intro-phone__media intro-phone__media--fullscreen">
                  {hasVideo ? (
                    <video
                      key={settings.introVideoURL}
                      src={settings.introVideoURL}
                      muted
                      playsInline
                      loop
                      autoPlay
                    />
                  ) : hasPoster ? (
                    <img src={settings.introImageURL} alt="" />
                  ) : (
                    <div className="intro-phone__placeholder">
                      <i className="fas fa-film" aria-hidden="true" />
                      <span>No video yet</span>
                      <em>Drop MP4 / MOV on the right</em>
                    </div>
                  )}
                </div>
                {settings.introEnabled && hasVideo ? (
                  <div className="intro-phone__chip" aria-hidden="true">
                    {durationLabel}
                  </div>
                ) : null}
                {!settings.introEnabled ? (
                  <div className="intro-phone__off" aria-hidden="true">
                    <span>Intro off</span>
                  </div>
                ) : null}
                <div className="intro-phone__home" aria-hidden="true" />
              </div>
            </div>
          </div>

          <div className="intro-stage__stats">
            <span className={`intro-stage__stat${settings.introEnabled ? ' is-on' : ''}`}>
              <i className="fas fa-power-off" aria-hidden="true" />
              {settings.introEnabled ? 'Enabled' : 'Disabled'}
            </span>
            <span className="intro-stage__stat">
              <i className="fas fa-clock" aria-hidden="true" />
              {durationLabel}
            </span>
            <span className={`intro-stage__stat${hasVideo ? ' is-on' : ''}`}>
              <i className="fas fa-video" aria-hidden="true" />
              {hasVideo ? 'Video ready' : 'No video'}
            </span>
          </div>
        </div>

        <aside className="intro-stage__editor">
          <section className="intro-card">
            <div className="intro-card__head">
              <h3>Playback</h3>
              <p>When and how long the intro runs.</p>
            </div>

            <div className="intro-card__row">
              <span>
                <strong>Enable intro</strong>
                <em>Cold start + leave/return · tap to skip</em>
              </span>
              <label
                className={`ads-mgmt__toggle${settings.introEnabled ? ' ads-mgmt__toggle--on' : ''}`}
              >
                <input
                  type="checkbox"
                  checked={settings.introEnabled}
                  disabled={disabled}
                  aria-checked={settings.introEnabled}
                  onChange={(e) => patch({ introEnabled: e.target.checked }, true)}
                />
                <i aria-hidden="true" />
              </label>
            </div>

            <div className="intro-card__block">
              <div className="intro-card__block-head">
                <strong>Copy</strong>
                <em>Optional text stored with intro settings</em>
              </div>
              <label className="intro-copy-field">
                <span>Title</span>
                <input
                  value={settings.introTitle}
                  disabled={disabled}
                  onChange={(e) => patch({ introTitle: e.target.value })}
                />
              </label>
              <label className="intro-copy-field">
                <span>Subtitle</span>
                <input
                  value={settings.introSubtitle}
                  disabled={disabled}
                  onChange={(e) => patch({ introSubtitle: e.target.value })}
                />
              </label>
              <label className="intro-copy-field">
                <span>Button</span>
                <input
                  value={settings.introButtonTitle}
                  disabled={disabled}
                  onChange={(e) => patch({ introButtonTitle: e.target.value })}
                />
              </label>
              <div className="intro-card__row intro-card__row--nested">
                <span>
                  <strong>Show every launch</strong>
                  <em>If off, only after version bump</em>
                </span>
                <label
                  className={`ads-mgmt__toggle${settings.introShowEveryLaunch ? ' ads-mgmt__toggle--on' : ''}`}
                >
                  <input
                    type="checkbox"
                    checked={settings.introShowEveryLaunch}
                    disabled={disabled}
                    aria-checked={settings.introShowEveryLaunch}
                    onChange={(e) => patch({ introShowEveryLaunch: e.target.checked }, true)}
                  />
                  <i aria-hidden="true" />
                </label>
              </div>
              <div className="intro-card__row intro-card__row--nested">
                <span>
                  <strong>Intro version</strong>
                  <em>Bump to force intro again for users who dismissed it</em>
                </span>
                <div className="intro-version">
                  <button
                    type="button"
                    className="intro-version__btn"
                    disabled={disabled || settings.introVersion <= 1}
                    aria-label="Decrease intro version"
                    onClick={() =>
                      patch({ introVersion: Math.max(1, settings.introVersion - 1) }, true)
                    }
                  >
                    −
                  </button>
                  <strong className="intro-version__value" aria-live="polite">
                    {settings.introVersion}
                  </strong>
                  <button
                    type="button"
                    className="intro-version__btn"
                    disabled={disabled}
                    aria-label="Bump intro version"
                    onClick={() => patch({ introVersion: settings.introVersion + 1 }, true)}
                  >
                    +
                  </button>
                </div>
              </div>
            </div>

            <div className="intro-card__block">
              <div className="intro-card__block-head">
                <strong>Max duration</strong>
                <em>0 keeps the full clip</em>
              </div>
              <div className="intro-duration">
                <div className="intro-duration__presets" role="group" aria-label="Duration presets">
                  {DURATION_PRESETS.map((preset) => {
                    const active = settings.introMaxSeconds === preset.value
                    return (
                      <button
                        key={preset.label}
                        type="button"
                        className={`intro-duration__chip${active ? ' is-on' : ''}`}
                        disabled={disabled}
                        onClick={() => patch({ introMaxSeconds: preset.value }, true)}
                      >
                        {preset.label}
                      </button>
                    )
                  })}
                </div>
                <label className="intro-duration__custom">
                  <span>Custom</span>
                  <input
                    className="settings-pro__num"
                    type="number"
                    min={0}
                    max={120}
                    value={settings.introMaxSeconds}
                    disabled={disabled}
                    onChange={(e) =>
                      patch(
                        {
                          introMaxSeconds: Math.max(
                            0,
                            Math.min(120, Math.floor(Number(e.target.value) || 0)),
                          ),
                        },
                        true,
                      )
                    }
                  />
                  <span>sec</span>
                </label>
              </div>
            </div>
          </section>

          <section className="intro-card">
            <div className="intro-card__head">
              <h3>Media</h3>
              <p>Upload to GitHub Releases · synced for the iOS app.</p>
            </div>

            <label
              className={`intro-drop${dragging ? ' intro-drop--active' : ''}${disabled ? ' intro-drop--disabled' : ''}${hasVideo ? ' intro-drop--filled' : ''}`}
              onDragEnter={(e) => {
                e.preventDefault()
                if (!disabled) setDragging(true)
              }}
              onDragOver={(e) => {
                e.preventDefault()
                if (!disabled) setDragging(true)
              }}
              onDragLeave={(e) => {
                e.preventDefault()
                setDragging(false)
              }}
              onDrop={onDrop}
            >
              <span className="intro-drop__icon" aria-hidden="true">
                <i className={`fas ${uploading ? 'fa-spinner fa-spin' : hasVideo ? 'fa-check' : 'fa-cloud-arrow-up'}`} />
              </span>
              <strong>
                {uploading ? 'Uploading…' : hasVideo ? 'Replace intro video' : 'Drop intro video'}
              </strong>
              <span>MP4 / MOV · under ~200MB</span>
              <input
                type="file"
                accept=".mp4,.mov,.m4v,video/mp4,video/quicktime,video/*"
                disabled={disabled}
                onChange={onPick}
              />
            </label>

            {hasVideo ? (
              <div className="intro-file">
                <div className="intro-file__meta">
                  <i className="fas fa-link" aria-hidden="true" />
                  <code title={settings.introVideoURL}>{shortUrl}</code>
                </div>
                <button type="button" disabled={disabled} onClick={clearVideo}>
                  Remove
                </button>
              </div>
            ) : null}
          </section>

          <p className="intro-stage__note">
            Every change publishes to GitHub <code>settings.json</code> automatically. Force-quit
            the iOS app and reopen to pick it up.
          </p>
        </aside>
      </div>
    </div>
  )
}
