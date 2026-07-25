import { initializeApp } from 'firebase/app'
import {
  GoogleAuthProvider,
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
  type User,
} from 'firebase/auth'
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  setDoc,
  writeBatch,
} from 'firebase/firestore'
import {
  DEFAULT_APP_SETTINGS,
  normalizeWallpaper,
  sortWallpapers,
  type AppSettings,
  type WallpaperRecord,
} from './types'
import { pushAppSettingsMirror } from './github'

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
}

const app = initializeApp(firebaseConfig)
export const db = getFirestore(app)
export const auth = getAuth(app)

export const ADMIN_UID = import.meta.env.VITE_ADMIN_UID as string

const wallpapersCollection = collection(db, 'wallpapers')
const settingsDoc = doc(db, 'settings', 'app')

export function isAdminUser(user: User | null): boolean {
  return Boolean(user && ADMIN_UID && user.uid === ADMIN_UID)
}

export function watchAuth(callback: (user: User | null) => void) {
  return onAuthStateChanged(auth, callback)
}

export async function loginWithEmail(email: string, password: string) {
  const result = await signInWithEmailAndPassword(auth, email, password)
  if (!isAdminUser(result.user)) {
    await signOut(auth)
    throw new Error('This account is not an admin.')
  }
  return result.user
}

export async function loginWithGoogle() {
  const provider = new GoogleAuthProvider()
  const result = await signInWithPopup(auth, provider)
  if (!isAdminUser(result.user)) {
    await signOut(auth)
    throw new Error('This Google account is not an admin.')
  }
  return result.user
}

export async function logout() {
  await signOut(auth)
}

export async function listWallpapers(): Promise<WallpaperRecord[]> {
  const snapshot = await getDocs(wallpapersCollection)
  const items = snapshot.docs.map((item) =>
    normalizeWallpaper({ id: item.id, ...(item.data() as Partial<WallpaperRecord>) }),
  )
  return sortWallpapers(items)
}

export async function saveWallpaper(record: WallpaperRecord): Promise<void> {
  await setDoc(doc(db, 'wallpapers', record.id), normalizeWallpaper(record))
}

export async function updateWallpaperFields(
  id: string,
  patch: Partial<Pick<WallpaperRecord, 'featured' | 'sortOrder' | 'title' | 'category'>>,
): Promise<WallpaperRecord> {
  const ref = doc(db, 'wallpapers', id)
  const snap = await getDoc(ref)
  if (!snap.exists()) {
    throw new Error('Wallpaper not found.')
  }
  const current = normalizeWallpaper({ id, ...(snap.data() as Partial<WallpaperRecord>) })
  const next = normalizeWallpaper({ ...current, ...patch, id })
  await setDoc(ref, next)
  return next
}

export async function saveWallpaperOrder(ordered: WallpaperRecord[]): Promise<WallpaperRecord[]> {
  const ranked = ordered.map((item, index) =>
    normalizeWallpaper({ ...item, sortOrder: index + 1 }),
  )

  // Firestore batches max 500
  for (let i = 0; i < ranked.length; i += 450) {
    const chunk = ranked.slice(i, i + 450)
    const batch = writeBatch(db)
    for (const item of chunk) {
      batch.set(doc(db, 'wallpapers', item.id), item)
    }
    await batch.commit()
  }

  return ranked
}

export async function removeWallpaper(id: string): Promise<void> {
  await deleteDoc(doc(db, 'wallpapers', id))
}

export async function loadAppSettings(): Promise<AppSettings> {
  const snap = await getDoc(settingsDoc)
  if (!snap.exists()) {
    return { ...DEFAULT_APP_SETTINGS }
  }
  const data = snap.data() as Partial<AppSettings> & {
    adsMode?: string
    interstitialEveryN?: number
  }
  const adsMode: AppSettings['adsMode'] =
    data.adsMode === 'production' ? 'production' : 'test'
  const legacyEvery = Math.max(1, Number(data.interstitialEveryN) || 3)
  return {
    ...DEFAULT_APP_SETTINGS,
    ...data,
    adsEnabled: Boolean(data.adsEnabled),
    adsMode,
    interstitialEveryNOpens: Math.max(
      1,
      Number(data.interstitialEveryNOpens) || legacyEvery,
    ),
    interstitialEveryNDownloads: Math.max(
      1,
      Number(data.interstitialEveryNDownloads) || legacyEvery,
    ),
    appOpenMinBackgroundSeconds: Math.max(
      0,
      Number(data.appOpenMinBackgroundSeconds) || 2,
    ),
    introEnabled: Boolean(data.introEnabled),
    introShowEveryLaunch: Boolean(data.introShowEveryLaunch),
    introVersion: Math.max(1, Math.floor(Number(data.introVersion) || 1)),
    introTitle: String(data.introTitle ?? DEFAULT_APP_SETTINGS.introTitle),
    introSubtitle: String(data.introSubtitle ?? DEFAULT_APP_SETTINGS.introSubtitle),
    introImageURL: String(data.introImageURL ?? ''),
    introVideoURL: String(data.introVideoURL ?? ''),
    introMaxSeconds: Math.max(
      0,
      Math.min(120, Math.floor(Number(data.introMaxSeconds) || 0)),
    ),
    introButtonTitle: String(
      data.introButtonTitle ?? DEFAULT_APP_SETTINGS.introButtonTitle,
    ),
    appOpenAdUnitId: String(data.appOpenAdUnitId ?? ''),
    interstitialAdUnitId: String(data.interstitialAdUnitId ?? ''),
    updatedAt: String(data.updatedAt ?? DEFAULT_APP_SETTINGS.updatedAt),
  }
}

export async function saveAppSettings(
  settings: AppSettings,
  options?: { mirror?: boolean },
): Promise<AppSettings> {
  const wantMirror = options?.mirror ?? true
  const next: AppSettings = {
    ...settings,
    adsEnabled: Boolean(settings.adsEnabled),
    introEnabled: Boolean(settings.introEnabled),
    introShowEveryLaunch: Boolean(settings.introShowEveryLaunch),
    interstitialEveryNOpens: Math.max(
      1,
      Math.floor(settings.interstitialEveryNOpens) || 4,
    ),
    interstitialEveryNDownloads: Math.max(
      1,
      Math.floor(settings.interstitialEveryNDownloads) || 3,
    ),
    appOpenMinBackgroundSeconds: Math.max(
      0,
      Math.min(600, Math.floor(settings.appOpenMinBackgroundSeconds) || 0),
    ),
    introVersion: Math.max(1, Math.floor(settings.introVersion) || 1),
    introTitle: settings.introTitle.trim() || DEFAULT_APP_SETTINGS.introTitle,
    introSubtitle: settings.introSubtitle.trim(),
    introImageURL: settings.introImageURL.trim(),
    introVideoURL: settings.introVideoURL.trim(),
    introMaxSeconds: Math.max(
      0,
      Math.min(120, Math.floor(settings.introMaxSeconds) || 0),
    ),
    introButtonTitle:
      settings.introButtonTitle.trim() || DEFAULT_APP_SETTINGS.introButtonTitle,
    updatedAt: new Date().toISOString(),
  }

  let firestoreOk = false
  try {
    await setDoc(settingsDoc, next, { merge: true })
    firestoreOk = true
  } catch (error) {
    console.warn('Firestore settings save failed.', error)
  }

  let mirrorOk = false
  let mirrorError: unknown
  if (wantMirror) {
    try {
      await pushAppSettingsMirror({
        adsEnabled: next.adsEnabled,
        adsMode: next.adsMode,
        appOpenAdUnitId: next.appOpenAdUnitId,
        interstitialAdUnitId: next.interstitialAdUnitId,
        interstitialEveryNOpens: next.interstitialEveryNOpens,
        interstitialEveryNDownloads: next.interstitialEveryNDownloads,
        appOpenMinBackgroundSeconds: next.appOpenMinBackgroundSeconds,
        introEnabled: next.introEnabled,
        introShowEveryLaunch: next.introShowEveryLaunch,
        introVersion: next.introVersion,
        introTitle: next.introTitle,
        introSubtitle: next.introSubtitle,
        introImageURL: next.introImageURL,
        introVideoURL: next.introVideoURL,
        introMaxSeconds: next.introMaxSeconds,
        introButtonTitle: next.introButtonTitle,
        updatedAt: next.updatedAt,
      })
      mirrorOk = true
    } catch (error) {
      mirrorError = error
      console.warn('GitHub settings mirror failed.', error)
    }
  }

  if (!firestoreOk && !mirrorOk) {
    throw new Error(
      mirrorError instanceof Error
        ? mirrorError.message
        : wantMirror
          ? 'Could not save settings (Firestore + GitHub both failed).'
          : 'Could not save settings to Firestore.',
    )
  }

  return next
}
