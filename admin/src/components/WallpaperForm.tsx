import { useEffect, useMemo, useRef, useState, type DragEvent, type FormEvent } from 'react'
import { Toast, useToast } from './Toast'
import { DEFAULT_CATEGORIES, LIVE_CATEGORY, slugify } from '../lib/categories'
import { saveWallpaper } from '../lib/firebase'
import { uploadLiveWallpaper, uploadWallpaperImages } from '../lib/github'
import { humanizeFetchError, sleep } from '../lib/image'
import type { WallpaperRecord } from '../lib/types'

type Props = {
  onCreated: (record: WallpaperRecord) => void
  onBatchComplete?: (created: WallpaperRecord[]) => Promise<void> | void
  /** Preselect catalog when opening Upload (e.g. from Live tab). */
  initialCategory?: string
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

function onlyVideos(list: FileList | File[]) {
  return Array.from(list).filter(
    (file) =>
      file.type.startsWith('video/') ||
      /\.(mp4|mov|m4v)$/i.test(file.name),
  )
}

function toQueueItems(files: File[], live: boolean): QueueItem[] {
  const accepted = live ? onlyVideos(files) : onlyImages(files)
  return accepted.map((file) => ({
    key: `${file.name}-${file.size}-${file.lastModified}-${crypto.randomUUID()}`,
    file,
    title: titleFromFile(file),
    previewUrl: URL.createObjectURL(file),
  }))
}

export function WallpaperForm({ onCreated, onBatchComplete, initialCategory }: Props) {
  const [category, setCategory] = useState(
    initialCategory && DEFAULT_CATEGORIES.some((item) => item.name === initialCategory)
      ? initialCategory
      : (DEFAULT_CATEGORIES[0]?.name ?? 'iOS 27'),
  )
  const [resolution, setResolution] = useState('4K')
  const [queue, setQueue] = useState<QueueItem[]>([])
  const [dragging, setDragging] = useState(false)
  const [busy, setBusy] = useState(false)
  const busyRef = useRef(false)
  const categoryRef = useRef(category)
  const queueRef = useRef(queue)
  const publishTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const { toast, show, clear } = useToast({ okDismissMs: 2200 })

  const isLiveCatalog = category === LIVE_CATEGORY.name

  queueRef.current = queue

  useEffect(() => {
    return () => {
      if (publishTimerRef.current) clearTimeout(publishTimerRef.current)
    }
  }, [])

  const countLabel = useMemo(() => {
    if (busy) return 'Publishing…'
    if (queue.length === 0) {
      return isLiveCatalog
        ? 'Drop MP4 / MOV · auto-publish (edit titles first)'
        : 'Auto-publishes on drop · edit titles first'
    }
    const unit = isLiveCatalog ? 'video' : 'image'
    if (queue.length === 1) return `1 ${unit} left`
    return `${queue.length} ${unit}s left`
  }, [busy, queue.length, isLiveCatalog])

  function selectCategory(next: string) {
    if (next === category) return
    clearQueue()
    categoryRef.current = next
    setCategory(next)
  }

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

  async function publishItems(items: QueueItem[], liveOverride?: boolean) {
    if (items.length === 0 || busyRef.current) return

    const catalogName = categoryRef.current
    const live = liveOverride ?? catalogName === LIVE_CATEGORY.name

    busyRef.current = true
    setBusy(true)
    clear()
    show('Publishing…', 'loading')

    let successCount = 0
    const failed: string[] = []
    const created: WallpaperRecord[] = []
    const okKeys: string[] = []

    try {
      for (let index = 0; index < items.length; index += 1) {
        const seeded = items[index]!
        const liveItem = queueRef.current.find((entry) => entry.key === seeded.key) ?? seeded
        const title = liveItem.title.trim() || titleFromFile(liveItem.file)
        const id = `${slugify(title)}-${Date.now().toString(36)}-${index}`

        show(`Uploading ${index + 1}/${items.length}: ${title}`, 'loading')

        try {
          const record: WallpaperRecord = live
            ? await (async () => {
                const uploaded = await uploadLiveWallpaper(id, liveItem.file)
                return {
                  id,
                  title,
                  imageURL: uploaded.imageURL,
                  thumbnailURL: uploaded.thumbnailURL,
                  videoURL: uploaded.videoURL,
                  category: LIVE_CATEGORY.name,
                  resolution: 'Live',
                  featured: false,
                  sortOrder: index + 1,
                  createdAt: new Date().toISOString(),
                }
              })()
            : await (async () => {
                const uploaded = await uploadWallpaperImages(id, liveItem.file)
                return {
                  id,
                  title,
                  imageURL: uploaded.imageURL,
                  thumbnailURL: uploaded.thumbnailURL,
                  category: catalogName,
                  resolution,
                  featured: false,
                  sortOrder: index + 1,
                  createdAt: new Date().toISOString(),
                }
              })()

          show(`Saving ${index + 1}/${items.length}…`, 'loading')
          await saveWallpaper(record)
          created.push(record)
          onCreated(record)
          okKeys.push(liveItem.key)
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
        show(`Syncing catalog (${created.length})…`, 'loading')
        try {
          await onBatchComplete?.(created)
        } catch (err) {
          failed.push(`Sync: ${humanizeFetchError(err, 'failed')}`)
        }
      }

      removeKeys(okKeys)

      if (failed.length === 0) {
        show(`Published ${successCount} wallpaper${successCount === 1 ? '' : 's'}.`)
      } else {
        show(
          `${successCount} published, ${failed.length} failed. Failed items stay in the queue.`,
          'error',
        )
      }
    } finally {
      busyRef.current = false
      setBusy(false)
    }
  }

  function scheduleAutoPublish(keys: string[], live: boolean) {
    if (publishTimerRef.current) clearTimeout(publishTimerRef.current)
    publishTimerRef.current = setTimeout(() => {
      publishTimerRef.current = null
      const latest = keys
        .map((key) => queueRef.current.find((item) => item.key === key))
        .filter((item): item is QueueItem => Boolean(item))
      if (latest.length > 0) void publishItems(latest, live)
    }, 900)
  }

  function addFiles(files: File[]) {
    if (busyRef.current) return

    const videos = onlyVideos(files)
    const images = onlyImages(files)

    // Videos always go to Live — even if Catalog was still on iOS 27.
    if (videos.length > 0 && images.length === 0) {
      categoryRef.current = LIVE_CATEGORY.name
      setCategory(LIVE_CATEGORY.name)
      const added = toQueueItems(videos, true)
      setQueue((prev) => [...prev, ...added])
      scheduleAutoPublish(
        added.map((item) => item.key),
        true,
      )
      return
    }

    if (images.length > 0 && videos.length === 0) {
      if (categoryRef.current === LIVE_CATEGORY.name) {
        show('Live Wallpapers needs MP4 or MOV. Switch to iOS 27 for images.', 'error')
        return
      }
      const added = toQueueItems(images, false)
      setQueue((prev) => [...prev, ...added])
      scheduleAutoPublish(
        added.map((item) => item.key),
        false,
      )
      return
    }

    if (videos.length > 0 && images.length > 0) {
      show('Drop videos or images separately — not mixed.', 'error')
      return
    }

    show(
      isLiveCatalog
        ? 'Add MP4 or MOV videos for Live Wallpapers.'
        : 'Add PNG or JPG images for iOS 27.',
      'error',
    )
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
      show(
        isLiveCatalog
          ? 'Add videos by drag & drop or file picker.'
          : 'Add images by drag & drop or file picker.',
        'error',
      )
      return
    }
    void publishItems([...queue])
  }

  return (
    <form className="upload-studio" onSubmit={onSubmit}>
      {toast ? <Toast message={toast.message} variant={toast.variant} /> : null}

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
                onClick={() => selectCategory(item.name)}
              >
                {item.label}
              </button>
            ))}
          </div>
        </div>

        {!isLiveCatalog ? (
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
        ) : (
          <div className="upload-field">
            <span className="upload-field__label">Format</span>
            <div className="upload-seg" role="status">
              <button type="button" className="upload-seg__btn upload-seg__btn--on" disabled>
                Live video
              </button>
            </div>
          </div>
        )}
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
          <i className={`fas ${isLiveCatalog ? 'fa-film' : 'fa-cloud-arrow-up'}`} />
        </span>
        <strong>{busy ? 'Publishing…' : isLiveCatalog ? 'Drop videos here' : 'Drop wallpapers here'}</strong>
        <span>
          {isLiveCatalog ? 'MP4 or MOV · publishes automatically' : 'PNG or JPG · publishes automatically'}
        </span>
        <em>{countLabel}</em>
        <input
          type="file"
          accept={
            isLiveCatalog
              ? '.mp4,.mov,.m4v,video/mp4,video/quicktime,video/*'
              : 'image/*,.png,.jpg,.jpeg,.webp'
          }
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
                  {isLiveCatalog ? (
                    <video src={item.previewUrl} muted playsInline preload="metadata" />
                  ) : (
                    <img src={item.previewUrl} alt="" />
                  )}
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
