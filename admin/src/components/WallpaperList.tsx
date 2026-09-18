import { useMemo, useState, type DragEvent } from 'react'
import { Toast, useToast } from './Toast'
import { removeWallpaper, saveWallpaperOrder, updateWallpaperFields } from '../lib/firebase'
import { replaceManifestWallpapers } from '../lib/github'
import { sortWallpapers, withRankOrder, type WallpaperRecord } from '../lib/types'
import {
  IOS_CATEGORY,
  LIVE_CATEGORY,
  isLiveCategory,
  matchesCategory,
  normalizeCategoryName,
} from '../lib/categories'

type DashboardFilter = 'all' | 'ios' | 'live' | 'featured'

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
  const [optimistic, setOptimistic] = useState<WallpaperRecord[] | null>(null)
  const [dragId, setDragId] = useState<string | null>(null)
  const [overId, setOverId] = useState<string | null>(null)
  const [dashboardFilter, setDashboardFilter] = useState<DashboardFilter>('all')
  const [query, setQuery] = useState('')
  const { toast, show, clear } = useToast()

  const categoryItems = useMemo(() => {
    if (showAll) return sortWallpapers(items)
    return sortWallpapers(items.filter((item) => matchesCategory(item.category, categoryName)))
  }, [items, categoryName, showAll])

  const iosCount = useMemo(
    () => items.filter((item) => matchesCategory(item.category, IOS_CATEGORY.name)).length,
    [items],
  )
  const liveCount = useMemo(
    () => items.filter((item) => matchesCategory(item.category, LIVE_CATEGORY.name)).length,
    [items],
  )
  const featuredCount = useMemo(() => items.filter((item) => item.featured).length, [items])

  const filteredItems = useMemo(() => {
    if (!showAll) return categoryItems
    const needle = query.trim().toLowerCase()
    return categoryItems.filter((item) => {
      if (dashboardFilter === 'ios' && !matchesCategory(item.category, IOS_CATEGORY.name)) {
        return false
      }
      if (dashboardFilter === 'live' && !matchesCategory(item.category, LIVE_CATEGORY.name)) {
        return false
      }
      if (dashboardFilter === 'featured' && !item.featured) return false
      if (needle && !item.title.toLowerCase().includes(needle)) return false
      return true
    })
  }, [showAll, categoryItems, dashboardFilter, query])

  const working = optimistic ?? filteredItems
  const canDrag = !showAll

  function mergeCategory(nextCategoryItems: WallpaperRecord[]) {
    if (showAll || !categoryName) {
      return nextCategoryItems
    }
    const others = sortWallpapers(
      items.filter((item) => !matchesCategory(item.category, categoryName)),
    )
    return [
      ...withRankOrder(nextCategoryItems.map((item) => ({ ...item, category: categoryName }))),
      ...others,
    ]
  }

  async function persistOrder(nextCategoryItems: WallpaperRecord[]) {
    if (showAll) return
    const rankedLocal = withRankOrder(nextCategoryItems)
    setOptimistic(rankedLocal)
    setBusyOrder(true)
    clear()
    show('Saving…', 'loading')
    try {
      const merged = mergeCategory(rankedLocal)
      const ranked = await saveWallpaperOrder(merged)
      try {
        await replaceManifestWallpapers(ranked)
        show('Order saved.')
      } catch (manifestError) {
        show(
          `Order saved. Manifest sync failed: ${
            manifestError instanceof Error ? manifestError.message : 'GitHub error'
          }`,
          'error',
        )
      }
      onChange(ranked)
      setOptimistic(null)
    } catch (err) {
      show(err instanceof Error ? err.message : 'Could not save order.', 'error')
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
    const [moved] = list.splice(from, 1)
    if (!moved) return
    list.splice(to, 0, moved)
    void persistOrder(list)
  }

  async function handleRemove(item: WallpaperRecord) {
    const ok = window.confirm(`Delete “${item.title}”? This cannot be undone.`)
    if (!ok) return

    clear()
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
        show('Deleted.')
      } catch (syncError) {
        onChange(merged)
        setOptimistic(null)
        show(
          `Deleted. Sync failed: ${
            syncError instanceof Error ? syncError.message : 'sync error'
          }`,
          'error',
        )
      }
    } catch (err) {
      show(err instanceof Error ? err.message : 'Delete failed.', 'error')
    } finally {
      setBusyId(null)
    }
  }

  async function handleFeaturedToggle(item: WallpaperRecord) {
    if (busyId || busyOrder) return
    clear()
    setBusyId(item.id)
    show(item.featured ? 'Unfeaturing…' : 'Featuring…', 'loading')
    try {
      const updated = await updateWallpaperFields(item.id, { featured: !item.featured })
      const next = items.map((entry) => (entry.id === item.id ? updated : entry))
      onChange(next)
      try {
        await replaceManifestWallpapers(next)
        show(updated.featured ? 'Featured.' : 'Removed from featured.')
      } catch (manifestError) {
        show(
          `Saved. Manifest sync failed: ${
            manifestError instanceof Error ? manifestError.message : 'GitHub error'
          }`,
          'error',
        )
      }
    } catch (err) {
      show(err instanceof Error ? err.message : 'Could not update featured.', 'error')
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
    <section className={`catalog${showAll ? ' catalog--dashboard' : ''}`}>
      {toast ? <Toast message={toast.message} variant={toast.variant} /> : null}

      {showAll ? (
        <div className="catalog-dash-stats">
          <button
            type="button"
            className={`catalog-dash-stat${dashboardFilter === 'all' ? ' is-on' : ''}`}
            onClick={() => setDashboardFilter('all')}
          >
            <span className="catalog-dash-stat__label">All</span>
            <strong className="catalog-dash-stat__value">{items.length}</strong>
          </button>
          <button
            type="button"
            className={`catalog-dash-stat${dashboardFilter === 'ios' ? ' is-on' : ''}`}
            onClick={() => setDashboardFilter('ios')}
          >
            <span className="catalog-dash-stat__label">iOS 27</span>
            <strong className="catalog-dash-stat__value">{iosCount}</strong>
          </button>
          <button
            type="button"
            className={`catalog-dash-stat${dashboardFilter === 'live' ? ' is-on' : ''}`}
            onClick={() => setDashboardFilter('live')}
          >
            <span className="catalog-dash-stat__label">Live</span>
            <strong className="catalog-dash-stat__value">{liveCount}</strong>
          </button>
          <button
            type="button"
            className={`catalog-dash-stat${dashboardFilter === 'featured' ? ' is-on' : ''}`}
            onClick={() => setDashboardFilter('featured')}
          >
            <span className="catalog-dash-stat__label">Featured</span>
            <strong className="catalog-dash-stat__value">{featuredCount}</strong>
          </button>
        </div>
      ) : null}

      <div className="catalog__bar">
        <p className="catalog__count">
          {working.length === 1 ? '1 item' : `${working.length} items`}
          {canDrag ? <span className="catalog__hint"> · drag to reorder</span> : null}
          {showAll && dashboardFilter !== 'all' ? (
            <span className="catalog__hint"> · filtered</span>
          ) : null}
        </p>
        {showAll ? (
          <label className="catalog__search">
            <i className="fas fa-search" aria-hidden="true" />
            <input
              type="search"
              value={query}
              placeholder="Search wallpapers…"
              onChange={(event) => setQuery(event.target.value)}
            />
          </label>
        ) : null}
        {busyOrder ? <p className="catalog__saving">Saving…</p> : null}
      </div>

      {working.length === 0 ? (
        <div className="empty-state">
          <p className="empty">
            {showAll && (dashboardFilter !== 'all' || query.trim())
              ? 'No wallpapers match this filter.'
              : 'No wallpapers here yet.'}
          </p>
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
            const live = Boolean(item.videoURL) || isLiveCategory(item.category)
            return (
              <li
                key={item.id}
                className={`catalog-card${dragging ? ' catalog-card--dragging' : ''}${
                  over ? ' catalog-card--over' : ''
                }${canDrag ? '' : ' catalog-card--static'}${item.featured ? ' catalog-card--featured' : ''}`}
                draggable={canDrag && !busyOrder && busyId === null}
                onDragStart={(event) => onDragStart(event, item.id)}
                onDragOver={(event) => onDragOver(event, item.id)}
                onDrop={(event) => onDrop(event, item.id)}
                onDragEnd={onDragEnd}
              >
                <img src={item.thumbnailURL} alt={item.title} loading="lazy" draggable={false} />
                {live && !showAll ? <span className="catalog-card__badge">Live</span> : null}
                <button
                  type="button"
                  className={`catalog-card__feature${item.featured ? ' is-on' : ''}`}
                  disabled={busyId === item.id || busyOrder}
                  onMouseDown={(event) => event.stopPropagation()}
                  onClick={(event) => {
                    event.stopPropagation()
                    void handleFeaturedToggle(item)
                  }}
                  aria-label={item.featured ? `Unfeature ${item.title}` : `Feature ${item.title}`}
                  aria-pressed={item.featured}
                  title={item.featured ? 'Featured' : 'Mark featured'}
                >
                  <i className="fas fa-star" aria-hidden="true" />
                </button>
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
