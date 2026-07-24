import { useMemo, useRef, useState, type DragEvent, type FormEvent } from 'react'
import { DEFAULT_CATEGORIES, slugify } from '../lib/categories'
import { saveWallpaper } from '../lib/firebase'
import { uploadWallpaperImages } from '../lib/github'
import { humanizeFetchError, sleep } from '../lib/image'
import type { WallpaperRecord } from '../lib/types'

type Props = {
  onCreated: (record: WallpaperRecord) => void
  onBatchComplete?: (created: WallpaperRecord[]) => Promise<void> | void
}

type QueueItem = {
  key: string
  file: File
  title: string
  previewUrl: string
}

const RESOLUTIONS = ['4K', '5K', '8K'] as const

function titleFromFile(file: File) {
  return file.name.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim() || 'Wallpaper'
}

function onlyImages(list: FileList | File[]) {
  return Array.from(list).filter((file) => file.type.startsWith('image/'))
}

function toQueueItems(files: File[]): QueueItem[] {
  return onlyImages(files).map((file) => ({
    key: `${file.name}-${file.size}-${file.lastModified}-${crypto.randomUUID()}`,
    file,
    title: titleFromFile(file),
    previewUrl: URL.createObjectURL(file),
  }))
}

export function WallpaperForm({ onCreated, onBatchComplete }: Props) {
  const [category, setCategory] = useState(DEFAULT_CATEGORIES[0]?.name ?? 'iOS 27')
  const [resolution, setResolution] = useState('4K')
  const [queue, setQueue] = useState<QueueItem[]>([])
  const [dragging, setDragging] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [status, setStatus] = useState<string | null>(null)
  const busyRef = useRef(false)

  const countLabel = useMemo(() => {
    if (busy) return 'Publishing…'
    if (queue.length === 0) return 'Auto-publishes on drop'
    if (queue.length === 1) return '1 image left'
    return `${queue.length} images left`
  }, [busy, queue.length])

  function removeItem(key: string) {
    setQueue((prev) => {
      const target = prev.find((item) => item.key === key)
      if (target) URL.revokeObjectURL(target.previewUrl)
      return prev.filter((item) => item.key !== key)
    })
  }

  function clearQueue() {
    setQueue((prev) => {
      prev.forEach((item) => URL.revokeObjectURL(item.previewUrl))
      return []
    })
  }

  function removeKeys(keys: string[]) {
    const drop = new Set(keys)
    setQueue((prev) => {
      prev.forEach((item) => {
        if (drop.has(item.key)) URL.revokeObjectURL(item.previewUrl)
      })
      return prev.filter((item) => !drop.has(item.key))
    })
  }

  async function publishItems(items: QueueItem[]) {
    if (items.length === 0 || busyRef.current) return

    busyRef.current = true
    setBusy(true)
    setError(null)
    setStatus(null)

    let successCount = 0
    const failed: string[] = []
    const created: WallpaperRecord[] = []
    const okKeys: string[] = []

    try {
      for (let index = 0; index < items.length; index += 1) {
        const item = items[index]!
        const title = item.title.trim() || titleFromFile(item.file)
        const id = `${slugify(title)}-${Date.now().toString(36)}-${index}`

        setStatus(`Uploading ${index + 1}/${items.length}: ${title}`)

        try {
          const uploaded = await uploadWallpaperImages(id, item.file)
          const record: WallpaperRecord = {
            id,
            title,
            imageURL: uploaded.imageURL,
            thumbnailURL: uploaded.thumbnailURL,
            category,
            resolution,
            featured: false,
            sortOrder: index + 1,
            createdAt: new Date().toISOString(),
          }

          setStatus(`Saving ${index + 1}/${items.length}…`)
          await saveWallpaper(record)
          created.push(record)
          onCreated(record)
          okKeys.push(item.key)
          successCount += 1

          if (index < items.length - 1) {
            await sleep(450)
          }
        } catch (err) {
          failed.push(`${title}: ${humanizeFetchError(err, 'failed')}`)
          await sleep(800)
        }
      }

      if (created.length > 0) {
        setStatus(`Syncing catalog (${created.length})…`)
        try {
          await onBatchComplete?.(created)
        } catch (err) {
          failed.push(`Sync: ${humanizeFetchError(err, 'failed')}`)
        }
      }

      removeKeys(okKeys)

      if (failed.length === 0) {
        setStatus(`Published ${successCount} wallpaper${successCount === 1 ? '' : 's'}.`)
      } else {
        setStatus(
          `${successCount} published, ${failed.length} failed. Failed items stay in the queue.`,
        )
        setError(failed.slice(0, 3).join(' · '))
      }
    } finally {
      busyRef.current = false
      setBusy(false)
    }
  }

  function addFiles(files: File[]) {
    if (busyRef.current) return

    const added = toQueueItems(files)
    if (added.length === 0) return

    setQueue((prev) => [...prev, ...added])
    setError(null)
    void publishItems(added)
  }

  function onDrop(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault()
    setDragging(false)
    if (busyRef.current) return
    addFiles(Array.from(event.dataTransfer.files))
  }

  function onSubmit(event: FormEvent) {
    event.preventDefault()
    if (queue.length === 0) {
      setError('Add images by drag & drop or file picker.')
      return
    }
    void publishItems([...queue])
  }

  return (
    <form className="upload-studio" onSubmit={onSubmit}>
      <div className="upload-studio__controls">
        <div className="upload-field">
          <span className="upload-field__label">Catalog</span>
          <div className="upload-seg" role="group" aria-label="Catalog">
            {DEFAULT_CATEGORIES.map((item) => (
              <button
                key={item.id}
                type="button"
                className={`upload-seg__btn${category === item.name ? ' upload-seg__btn--on' : ''}`}
                disabled={busy}
                onClick={() => setCategory(item.name)}
              >
                {item.label}
              </button>
            ))}
          </div>
        </div>

        <div className="upload-field">
          <span className="upload-field__label">Resolution</span>
          <div className="upload-seg upload-seg--compact" role="group" aria-label="Resolution">
            {RESOLUTIONS.map((value) => (
              <button
                key={value}
                type="button"
                className={`upload-seg__btn${resolution === value ? ' upload-seg__btn--on' : ''}`}
                disabled={busy}
                onClick={() => setResolution(value)}
              >
                {value}
              </button>
            ))}
          </div>
        </div>
      </div>

      <label
        className={`upload-drop${dragging ? ' upload-drop--active' : ''}${busy ? ' upload-drop--disabled' : ''}${queue.length > 0 ? ' upload-drop--filled' : ''}`}
        onDragEnter={(event) => {
          event.preventDefault()
          if (!busy) setDragging(true)
        }}
        onDragOver={(event) => {
          event.preventDefault()
          if (!busy) setDragging(true)
        }}
        onDragLeave={(event) => {
          event.preventDefault()
          setDragging(false)
        }}
        onDrop={onDrop}
      >
        <span className="upload-drop__icon" aria-hidden="true">
          <i className="fas fa-cloud-arrow-up" />
        </span>
        <strong>{busy ? 'Publishing…' : 'Drop wallpapers here'}</strong>
        <span>PNG or JPG · publishes automatically</span>
        <em>{countLabel}</em>
        <input
          type="file"
          accept="image/*"
          multiple
          disabled={busy}
          onChange={(event) => {
            addFiles(Array.from(event.target.files ?? []))
            event.target.value = ''
          }}
        />
      </label>

      {queue.length > 0 ? (
        <div className="upload-queue">
          <div className="upload-queue__head">
            <h3>{busy ? 'Uploading' : 'Queue'}</h3>
            <span>{queue.length}</span>
          </div>
          <ul className="upload-queue__grid">
            {queue.map((item) => (
              <li key={item.key} className="upload-queue__card">
                <div className="upload-queue__thumb">
                  <img src={item.previewUrl} alt="" />
                  <button
                    type="button"
                    className="upload-queue__remove"
                    disabled={busy}
                    onClick={() => removeItem(item.key)}
                    aria-label={`Remove ${item.title}`}
                  >
                    ×
                  </button>
                </div>
                <input
                  className="upload-queue__title"
                  value={item.title}
                  disabled={busy}
                  onChange={(event) => {
                    const value = event.target.value
                    setQueue((prev) =>
                      prev.map((entry) =>
                        entry.key === item.key ? { ...entry, title: value } : entry,
                      ),
                    )
                  }}
                />
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      {error ? <p className="banner banner--error">{error}</p> : null}
      {status ? <p className="banner banner--ok">{status}</p> : null}

      {queue.length > 0 && !busy ? (
        <div className="upload-studio__footer">
          <button className="btn-primary" type="submit">
            <i className="fas fa-paper-plane" aria-hidden="true" />
            Retry publish
          </button>
          <button type="button" className="ghost-btn" onClick={clearQueue}>
            Clear all
          </button>
        </div>
      ) : null}
    </form>
  )
}
