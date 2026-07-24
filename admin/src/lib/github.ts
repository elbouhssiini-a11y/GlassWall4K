import type { WallpaperManifest, WallpaperRecord } from './types'
import { DEFAULT_CATEGORIES } from './categories'
import { humanizeFetchError, makeThumbnail } from './image'

const owner = import.meta.env.VITE_GITHUB_OWNER as string
const repo = import.meta.env.VITE_GITHUB_REPO as string
const branch = (import.meta.env.VITE_GITHUB_BRANCH as string) || 'main'
const token = import.meta.env.VITE_GITHUB_TOKEN as string

function requireToken() {
  if (!token) {
    throw new Error('VITE_GITHUB_TOKEN khawi. Zido f admin/.env.local')
  }
}

function readHeaders() {
  requireToken()
  return {
    Accept: 'application/vnd.github+json',
    Authorization: `Bearer ${token}`,
    'X-GitHub-Api-Version': '2022-11-28',
  }
}

function writeHeaders() {
  return {
    ...readHeaders(),
    'Content-Type': 'application/json',
  }
}

function rawUrl(path: string) {
  return `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${path}`
}

function toBase64Json(value: unknown) {
  return btoa(unescape(encodeURIComponent(JSON.stringify(value, null, 2))))
}

async function fileToBase64(file: Blob): Promise<string> {
  const buffer = await file.arrayBuffer()
  let binary = ''
  const bytes = new Uint8Array(buffer)
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
}

type GitHubContentFile = {
  sha: string
  content?: string
  encoding?: string
}

async function getContentFile(path: string): Promise<GitHubContentFile | null> {
  const response = await fetch(
    `https://api.github.com/repos/${owner}/${repo}/contents/${path}?ref=${branch}&t=${Date.now()}`,
    { headers: readHeaders(), cache: 'no-store' },
  )

  if (response.status === 404) return null
  if (!response.ok) {
    const body = await response.text()
    throw new Error(`GitHub read failed (${response.status}): ${body}`)
  }

  return (await response.json()) as GitHubContentFile
}

async function putFile(path: string, contentBase64: string, message: string, sha?: string) {
  const response = await fetch(`https://api.github.com/repos/${owner}/${repo}/contents/${path}`, {
    method: 'PUT',
    headers: writeHeaders(),
    body: JSON.stringify({
      message,
      content: contentBase64,
      branch,
      ...(sha ? { sha } : {}),
    }),
  })

  const body = await response.text()

  if (response.status === 409) {
    const error = new Error(`GitHub conflict (409): ${body}`) as Error & { status: number }
    error.status = 409
    throw error
  }

  if (!response.ok) {
    throw new Error(`GitHub upload failed (${response.status}): ${body}`)
  }

  return JSON.parse(body)
}

async function putFileWithRetry(path: string, contentBase64: string, message: string) {
  let lastError: unknown

  for (let attempt = 0; attempt < 6; attempt += 1) {
    const current = await getContentFile(path)
    try {
      return await putFile(path, contentBase64, message, current?.sha)
    } catch (error) {
      lastError = error
      const status = (error as { status?: number }).status
      if (status !== 409) throw error
      await new Promise((resolve) => setTimeout(resolve, 400 * (attempt + 1)))
    }
  }

  throw lastError instanceof Error ? lastError : new Error('GitHub upload failed after retries.')
}

function parseManifestFromContentFile(file: GitHubContentFile | null): WallpaperManifest {
  if (!file?.content) {
    return { categories: DEFAULT_CATEGORIES, wallpapers: [] }
  }

  const decoded = decodeURIComponent(escape(atob(file.content.replace(/\n/g, ''))))
  const parsed = JSON.parse(decoded) as WallpaperManifest
    return {
      categories: DEFAULT_CATEGORIES,
      wallpapers: parsed.wallpapers ?? [],
    }
}

export async function uploadWallpaperImages(id: string, file: File) {
  try {
    const extension = file.name.split('.').pop()?.toLowerCase() || 'jpg'
    const fullPath = `wallpapers/${id}/full.${extension}`
    const thumbPath = `wallpapers/${id}/thumb.jpg`

    const thumbBlob = await makeThumbnail(file)
    const fullContent = await fileToBase64(file)
    const thumbContent = await fileToBase64(thumbBlob)

    await putFileWithRetry(fullPath, fullContent, `Add wallpaper full image: ${id}`)
    await putFileWithRetry(thumbPath, thumbContent, `Add wallpaper thumb image: ${id}`)

    return {
      imageURL: rawUrl(fullPath),
      thumbnailURL: rawUrl(thumbPath),
      fullPath,
      thumbPath,
    }
  } catch (error) {
    throw new Error(humanizeFetchError(error, 'GitHub upload fail'))
  }
}

export async function readManifest(): Promise<WallpaperManifest> {
  const file = await getContentFile('manifest.json')
  if (file) return parseManifestFromContentFile(file)

  const response = await fetch(`${rawUrl('manifest.json')}?t=${Date.now()}`)
  if (!response.ok) {
    return { categories: DEFAULT_CATEGORIES, wallpapers: [] }
  }
  return (await response.json()) as WallpaperManifest
}

async function writeManifest(
  mutate: (current: WallpaperManifest) => WallpaperManifest,
  message: string,
) {
  let lastError: unknown

  for (let attempt = 0; attempt < 8; attempt += 1) {
    const file = await getContentFile('manifest.json')
    const current = parseManifestFromContentFile(file)
    const next = mutate(current)
    const content = toBase64Json(next)

    try {
      await putFile('manifest.json', content, message, file?.sha)
      return next
    } catch (error) {
      lastError = error
      const status = (error as { status?: number }).status
      if (status !== 409) throw error
      await new Promise((resolve) => setTimeout(resolve, 500 * (attempt + 1)))
    }
  }

  throw lastError instanceof Error ? lastError : new Error('Manifest sync failed after retries.')
}

export async function upsertManifestWallpaper(record: WallpaperRecord) {
  return upsertManifestWallpapers([record])
}

export async function upsertManifestWallpapers(records: WallpaperRecord[]) {
  if (records.length === 0) {
    return readManifest()
  }

  return writeManifest((current) => {
    const byId = new Map<string, WallpaperRecord>()
    for (const item of current.wallpapers) {
      byId.set(item.id, item)
    }
    for (const item of records) {
      byId.set(item.id, item)
    }

    const wallpapers = [...byId.values()].sort((a, b) => {
      const ao = typeof a.sortOrder === 'number' ? a.sortOrder : 9999
      const bo = typeof b.sortOrder === 'number' ? b.sortOrder : 9999
      if (ao !== bo) return ao - bo
      return String(b.createdAt).localeCompare(String(a.createdAt))
    })

    return {
      categories: DEFAULT_CATEGORIES,
      wallpapers,
    }
  }, `Upsert ${records.length} wallpaper(s) in manifest`)
}

export async function replaceManifestWallpapers(wallpapers: WallpaperRecord[]) {
  return writeManifest(() => {
    return {
      categories: DEFAULT_CATEGORIES,
      wallpapers: [...wallpapers].sort((a, b) => {
        const ao = typeof a.sortOrder === 'number' ? a.sortOrder : 9999
        const bo = typeof b.sortOrder === 'number' ? b.sortOrder : 9999
        if (ao !== bo) return ao - bo
        return String(b.createdAt).localeCompare(String(a.createdAt))
      }),
    }
  }, `Replace wallpaper order in manifest (${wallpapers.length})`)
}

export async function removeManifestWallpaper(id: string) {
  try {
    return await writeManifest((current) => {
      return {
        categories: DEFAULT_CATEGORIES,
        wallpapers: current.wallpapers.filter((item) => item.id !== id),
      }
    }, `Remove wallpaper from manifest: ${id}`)
  } catch (error) {
    if (error instanceof TypeError && String(error.message).includes('fetch')) {
      throw new Error(
        'GitHub API blocked (CORS/network). Check VITE_GITHUB_TOKEN w Brave shields.',
      )
    }
    throw error
  }
}
