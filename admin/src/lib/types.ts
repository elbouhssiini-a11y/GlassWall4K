export type WallpaperRecord = {
  id: string
  title: string
  imageURL: string
  thumbnailURL: string
  category: string
  resolution: string
  featured: boolean
  /** Rank in app catalog. 1 = #1 (top). */
  sortOrder: number
  createdAt: string
}

export type CategoryRecord = {
  id: string
  /** Stored in Firestore / manifest. */
  name: string
  /** Shown in the admin UI. */
  label: string
  icon: string
}

export type WallpaperManifest = {
  categories: CategoryRecord[]
  wallpapers: WallpaperRecord[]
}

export type WallpaperInput = {
  title: string
  category: string
  resolution: string
  featured: boolean
  file: File
}

export type AdsMode = 'test' | 'production'

export type AppSettings = {
  adsEnabled: boolean
  /** test = Google demo units in app · production = your AdMob units */
  adsMode: AdsMode
  appOpenAdUnitId: string
  interstitialAdUnitId: string
  /** Show interstitial every N wallpaper detail opens. */
  interstitialEveryNOpens: number
  /** Show interstitial every N successful downloads. */
  interstitialEveryNDownloads: number
  updatedAt: string
}

/** Official Google AdMob iOS demo units (safe for testing). */
export const IOS_TEST_AD_UNITS = {
  appOpen: 'ca-app-pub-3940256099942544/5575463023',
  interstitial: 'ca-app-pub-3940256099942544/4411468910',
} as const

export const DEFAULT_APP_SETTINGS: AppSettings = {
  adsEnabled: false,
  adsMode: 'test',
  appOpenAdUnitId: '',
  interstitialAdUnitId: '',
  interstitialEveryNOpens: 3,
  interstitialEveryNDownloads: 3,
  updatedAt: new Date(0).toISOString(),
}

/** IDs the app should actually load. */
export function resolveAdUnitIds(settings: AppSettings) {
  if (settings.adsMode === 'test') {
    return {
      appOpenAdUnitId: IOS_TEST_AD_UNITS.appOpen,
      interstitialAdUnitId: IOS_TEST_AD_UNITS.interstitial,
    }
  }
  return {
    appOpenAdUnitId: settings.appOpenAdUnitId.trim(),
    interstitialAdUnitId: settings.interstitialAdUnitId.trim(),
  }
}

export function normalizeWallpaper(raw: Partial<WallpaperRecord> & { id: string }): WallpaperRecord {
  return {
    id: raw.id,
    title: raw.title ?? 'Wallpaper',
    imageURL: raw.imageURL ?? '',
    thumbnailURL: raw.thumbnailURL ?? '',
    category: raw.category ?? 'iOS 27',
    resolution: raw.resolution ?? '4K',
    featured: Boolean(raw.featured),
    sortOrder: typeof raw.sortOrder === 'number' && Number.isFinite(raw.sortOrder) ? raw.sortOrder : 9999,
    createdAt: raw.createdAt ?? new Date().toISOString(),
  }
}

export function sortWallpapers(items: WallpaperRecord[]): WallpaperRecord[] {
  return [...items].sort((a, b) => {
    if (a.sortOrder !== b.sortOrder) return a.sortOrder - b.sortOrder
    return b.createdAt.localeCompare(a.createdAt)
  })
}

/** Assign #1…n from the current array order (do not re-sort). */
export function withRankOrder(items: WallpaperRecord[]): WallpaperRecord[] {
  return items.map((item, index) => ({
    ...item,
    sortOrder: index + 1,
  }))
}

/** Rank #1…n inside each category independently (matches app tabs). */
export function withCategoryRankOrder(
  items: WallpaperRecord[],
  categoryNames: string[],
): WallpaperRecord[] {
  const known = new Set(categoryNames)
  const ranked: WallpaperRecord[] = []
  const claimed = new Set<string>()

  for (const name of categoryNames) {
    const group = items
      .filter((item) => {
        if (claimed.has(item.id)) return false
        if (item.category === name) return true
        if (name === 'iOS 27' && (item.category === 'iOS Wallpapers' || item.category === 'iOS 27')) {
          return true
        }
        return false
      })
      .map((item) => ({ ...item, category: name }))
    group.forEach((item) => claimed.add(item.id))
    ranked.push(...withRankOrder(group))
  }

  const orphans = items.filter((item) => !claimed.has(item.id) && !known.has(item.category))
  ranked.push(...withRankOrder(orphans))
  return ranked
}
