import { useMemo, useState, type DragEvent } from 'react'
import { removeWallpaper, saveWallpaperOrder } from '../lib/firebase'
import { replaceManifestWallpapers } from '../lib/github'
import { sortWallpapers, withRankOrder, type WallpaperRecord } from '../lib/types'
import { matchesCategory, normalizeCategoryName } from '../lib/categories'

type Props = {
  items: WallpaperRecord[]
  /** When omitted, shows all wallpapers (no drag reorder). */
  categoryName?: string
  onChange: (items: WallpaperRecord[]) => void
  onUploadClick?: () => void
}

export function WallpaperList({ items, categoryName, onChange, onUploadClick }: Props) {
  const showAll = !categoryName
  const [busyId, setBusyId] = useState<string | null>(null)
  const [busyOrder, setBusyOrder] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [optimistic, setOptimistic] = useState<WallpaperRecord[] | null>(null)
  const [dragId, setDragId] = useState<string | null>(null)
  const [overId, setOverId] = useState<string | null>(null)

  const categoryItems = useMemo(() => {
    if (showAll) return sortWallpapers(items)
    return sortWallpapers(items.filter((item) => matchesCategory(item.category, categoryName)))
  }, [items, categoryName, showAll])

  const working = optimistic ?? categoryItems
  const canDrag = !showAll

  function mergeCategory(nextCategoryItems: WallpaperRecord[]) {
    if (showAll || !categoryName) {
      return nextCategoryItems
    }
    const others = items.filter((item) => !matchesCategory(item.category, categoryName))
    return [
      ...withRankOrder(nextCategoryItems.map((item) => ({ ...item, category: categoryName }))),
      ...others,
    ]
  }

  async function persistOrder(nextCategoryItems: WallpaperRecord[]) {
    if (showAll) return
    // Keep the dragged array order; only assign new sortOrder ranks.
    const rankedLocal = withRankOrder(nextCategoryItems)
    setOptimistic(rankedLocal)
    setBusyOrder(true)
    setError(null)
    setNotice(null)
    try {
      const merged = mergeCategory(rankedLocal)
      const ranked = await saveWallpaperOrder(merged)
      try {
        await replaceManifestWallpapers(ranked)
        setNotice('Order saved.')
      } catch (manifestError) {
        setNotice(
          `Order saved. Manifest sync failed: ${
            manifestError instanceof Error ? manifestError.message : 'GitHub error'
          }`,
        )
      }
      onChange(ranked)
      // Keep optimistic until parent items reflect the new order.
      setOptimistic(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save order.')
      setOptimistic(null)
    } finally {
      setBusyOrder(false)
    }
  }

  function reorderByDrag(fromId: string, toId: string) {
    if (!canDrag || fromId === toId || busyOrder) return
    const list = [...working]
    const from = list.findIndex((item) => item.id === fromId)
    const to = list.findIndex((item) => item.id === toId)
    if (from < 0 || to < 0) return
    ;[list[from], list[to]] = [list[to], list[from]]
    void persistOrder(list)
  }

  async function handleRemove(item: WallpaperRecord) {
    setError(null)
    setNotice(null)
    setBusyId(item.id)

    try {
      await removeWallpaper(item.id)
      const remaining = items.filter((entry) => entry.id !== item.id)
      const targetCategory = categoryName ?? normalizeCategoryName(item.category)
      const nextCategory = withRankOrder(
        remaining.filter((entry) => matchesCategory(entry.category, targetCategory)),
      ).map((entry) => ({ ...entry, category: targetCategory }))
      const others = remaining.filter((entry) => !matchesCategory(entry.category, targetCategory))
      const merged = [...nextCategory, ...others]

      try {
        const ranked = await saveWallpaperOrder(merged)
        onChange(ranked)
        setOptimistic(null)
        await replaceManifestWallpapers(ranked)
        setNotice('Deleted.')
      } catch (syncError) {
        onChange(merged)
        setOptimistic(null)
        setNotice(
          `Deleted. Sync failed: ${
            syncError instanceof Error ? syncError.message : 'sync error'
          }`,
        )
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Delete failed.')
    } finally {
      setBusyId(null)
    }
  }

  function onDragStart(event: DragEvent<HTMLLIElement>, id: string) {
    if (!canDrag || busyOrder || busyId) {
      event.preventDefault()
      return
    }
    setDragId(id)
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', id)
  }

  function onDragOver(event: DragEvent<HTMLLIElement>, id: string) {
    if (!canDrag) return
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    if (overId !== id) setOverId(id)
  }

  function onDrop(event: DragEvent<HTMLLIElement>, id: string) {
    if (!canDrag) return
    event.preventDefault()
    const fromId = event.dataTransfer.getData('text/plain') || dragId
    if (fromId) reorderByDrag(fromId, id)
    setDragId(null)
    setOverId(null)
  }

  function onDragEnd() {
    setDragId(null)
    setOverId(null)
  }

  return (
    <section className="catalog">
      <div className="catalog__bar">
        <p className="catalog__count">
          {working.length === 1 ? '1 item' : `${working.length} items`}
          {canDrag ? <span className="catalog__hint"> · drag to swap</span> : null}
        </p>
        {busyOrder ? <p className="catalog__saving">Saving…</p> : null}
      </div>

      {error ? <p className="banner banner--error">{error}</p> : null}
      {notice ? <p className="banner banner--ok">{notice}</p> : null}

      {working.length === 0 ? (
        <div className="empty-state">
          <p className="empty">No wallpapers here yet.</p>
          {onUploadClick ? (
            <button type="button" className="primary-btn" onClick={onUploadClick}>
              Upload
            </button>
          ) : null}
        </div>
      ) : (
        <ul className="catalog-grid">
          {working.map((item) => {
            const dragging = dragId === item.id
            const over = overId === item.id && dragId !== item.id
            return (
              <li
                key={item.id}
                className={`catalog-card${dragging ? ' catalog-card--dragging' : ''}${
                  over ? ' catalog-card--over' : ''
                }${canDrag ? '' : ' catalog-card--static'}`}
                draggable={canDrag && !busyOrder && busyId === null}
                onDragStart={(event) => onDragStart(event, item.id)}
                onDragOver={(event) => onDragOver(event, item.id)}
                onDrop={(event) => onDrop(event, item.id)}
                onDragEnd={onDragEnd}
              >
                <img src={item.thumbnailURL} alt={item.title} loading="lazy" draggable={false} />
                <button
                  type="button"
                  className="catalog-card__delete"
                  disabled={busyId === item.id || busyOrder}
                  onMouseDown={(event) => event.stopPropagation()}
                  onClick={(event) => {
                    event.stopPropagation()
                    void handleRemove(item)
                  }}
                  aria-label={`Delete ${item.title}`}
                >
                  {busyId === item.id ? '…' : '×'}
                </button>
              </li>
            )
          })}
        </ul>
      )}
    </section>
  )
}
