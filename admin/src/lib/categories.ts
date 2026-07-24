import type { CategoryRecord } from './types'

export const DEFAULT_CATEGORIES: CategoryRecord[] = [
  { id: 'ios-wallpapers', name: 'iOS 27', label: 'iOS 27 Wallpapers', icon: 'iphone' },
  { id: '4k-wallpapers', name: '4K Wallpapers', label: '4K Wallpapers', icon: '4k.tv' },
]

export const IOS_CATEGORY = DEFAULT_CATEGORIES[0]!
export const FOUR_K_CATEGORY = DEFAULT_CATEGORIES[1]!

/** Legacy Firestore/manifest values still accepted as iOS 27. */
const IOS_ALIASES = new Set(['iOS 27', 'iOS Wallpapers', 'iOS 27 Wallpapers'])

export function isIosCategory(name: string): boolean {
  return IOS_ALIASES.has(name)
}

export function matchesCategory(itemCategory: string, categoryName: string): boolean {
  if (itemCategory === categoryName) return true
  if (categoryName === IOS_CATEGORY.name && isIosCategory(itemCategory)) return true
  return false
}

export function normalizeCategoryName(name: string): string {
  if (isIosCategory(name)) return IOS_CATEGORY.name
  return name
}

export function slugify(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}
