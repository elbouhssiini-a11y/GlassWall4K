import { useMemo } from 'react'
import { getGithubAssetConfig } from '../lib/github'
import { IOS_CATEGORY, LIVE_CATEGORY } from '../lib/categories'
import { usePageStatus, type PageStatus } from './StatusBadge'

const COLLECTIONS = [
  {
    label: 'iOS 27 Wallpapers',
    value: IOS_CATEGORY.name,
    note: 'Catalog category',
  },
  {
    label: 'Live Wallpapers',
    value: LIVE_CATEGORY.name,
    note: 'Catalog category',
  },
  {
    label: 'Intro',
    value: 'settings / intro-assets',
    note: 'App settings + GitHub Release',
  },
] as const

const RULES = [
  'iOS 27 Wallpapers accept image files only',
  'Live Wallpapers accept video files only',
  'Intro accepts video files only',
  'Uploads publish automatically to the catalog',
] as const

type Props = {
  onStatusChange?: (status: PageStatus | null) => void
}

export function ConfigPanel({ onStatusChange }: Props) {
  const github = getGithubAssetConfig()

  const status = useMemo<PageStatus>(
    () => ({
      tone: github.ok ? 'ok' : 'off',
      label: github.ok ? 'Configuration Loaded' : 'Configuration Incomplete',
      title: github.ok
        ? 'GitHub env is configured'
        : `Missing: ${github.issues.join(', ')}`,
    }),
    [github.ok, github.issues],
  )

  usePageStatus(status, onStatusChange)

  const githubRows = [
    { label: 'Repository', value: github.repository },
    { label: 'Branch', value: github.branch },
    { label: 'Images Folder', value: github.imagesFolder },
    { label: 'Videos Folder', value: `${github.videosFolder} (same as images)` },
    { label: 'Intro Release', value: github.introRelease },
  ]

  return (
    <div className="cfg-panel">
      <div className="cfg-panel__grid">
        <section className="cfg-card">
          <header className="cfg-card__head">
            <h2>Content Collections</h2>
            <p>Catalog categories in Firestore, plus intro media settings.</p>
          </header>
          <ul className="cfg-rows">
            {COLLECTIONS.map((row) => (
              <li key={row.label} className="cfg-row">
                <span>
                  {row.label}
                  <em className="cfg-row__note">{row.note}</em>
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
              <li key={row.label} className="cfg-row">
                <span>{row.label}</span>
                <code>{row.value}</code>
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
    </div>
  )
}
