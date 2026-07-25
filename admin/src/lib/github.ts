import type { WallpaperManifest, WallpaperRecord } from './types'
import { DEFAULT_CATEGORIES } from './categories'
import { humanizeFetchError, makeThumbnail, makeVideoThumbnail } from './image'

const owner = import.meta.env.VITE_GITHUB_OWNER as string
const repo = import.meta.env.VITE_GITHUB_REPO as string
const branch = (import.meta.env.VITE_GITHUB_BRANCH as string) || 'main'
const token = import.meta.env.VITE_GITHUB_TOKEN as string

export function getGithubAssetConfig() {
  const hasOwner = Boolean(owner?.trim())
  const hasRepo = Boolean(repo?.trim())
  const hasToken = Boolean(token?.trim())
  const issues: string[] = []
  if (!hasOwner) issues.push('VITE_GITHUB_OWNER')
  if (!hasRepo) issues.push('VITE_GITHUB_REPO')
  if (!hasToken) issues.push('VITE_GITHUB_TOKEN')

  return {
    repository: hasOwner && hasRepo ? `${owner}/${repo}` : '—',
    branch: branch || 'main',
    imagesFolder: 'wallpapers/',
    videosFolder: 'wallpapers/',
    /** Intro media is stored on the GitHub Release tag, not a repo folder. */
    introRelease: 'intro-assets',
    ok: issues.length === 0,
    issues,
  }
}

/** Same-origin Vite proxy → bypasses browser CORS / Brave shields. */
function githubApi(path: string) {
  const clean = path.startsWith('/') ? path : `/${path}`
  return `/github-api${clean}`
}

function githubUploads(path: string) {
  const clean = path.startsWith('/') ? path : `/${path}`
  return `/github-uploads${clean}`
}

function requireToken() {
  if (!token) {
    throw new Error('VITE_GITHUB_TOKEN is missing. Add it in admin/.env.local')
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
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => {
      const result = reader.result
      if (typeof result !== 'string') {
        reject(new Error('Could not encode file'))
        return
      }
      const comma = result.indexOf(',')
      resolve(comma >= 0 ? result.slice(comma + 1) : result)
    }
    reader.onerror = () => reject(reader.error ?? new Error('File read failed'))
    reader.readAsDataURL(file)
  })
}

type GitHubContentFile = {
  sha: string
  content?: string
  encoding?: string
}

async function getContentFile(path: string): Promise<GitHubContentFile | null> {
  const response = await fetch(
    githubApi(`/repos/${owner}/${repo}/contents/${path}?ref=${branch}&t=${Date.now()}`),
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
  const response = await fetch(githubApi(`/repos/${owner}/${repo}/contents/${path}`), {
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

/** Contents API rejects larger binaries (~25MB). Git Data API supports up to ~100MB. */
const CONTENTS_API_SAFE_BYTES = 20 * 1024 * 1024
const GIT_BLOB_MAX_BYTES = 95 * 1024 * 1024

type GitFilePayload = {
  path: string
  contentBase64: string
}

async function createGitBlob(contentBase64: string): Promise<string> {
  const response = await fetch(githubApi(`/repos/${owner}/${repo}/git/blobs`), {
    method: 'POST',
    headers: writeHeaders(),
    body: JSON.stringify({
      content: contentBase64,
      encoding: 'base64',
    }),
  })
  const body = await response.text()
  if (!response.ok) {
    throw new Error(`GitHub blob create failed (${response.status}): ${body}`)
  }
  const json = JSON.parse(body) as { sha?: string }
  if (!json.sha) throw new Error('GitHub blob create returned no sha.')
  return json.sha
}

async function commitFilesViaGitAPI(files: GitFilePayload[], message: string) {
  if (files.length === 0) return

  let lastError: unknown
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      const blobShas = await Promise.all(files.map((file) => createGitBlob(file.contentBase64)))

      const refResponse = await fetch(
        githubApi(`/repos/${owner}/${repo}/git/ref/heads/${branch}`),
        { headers: readHeaders(), cache: 'no-store' },
      )
      const refBody = await refResponse.text()
      if (!refResponse.ok) {
        throw new Error(`GitHub ref read failed (${refResponse.status}): ${refBody}`)
      }
      const refJson = JSON.parse(refBody) as { object?: { sha?: string } }
      const parentSha = refJson.object?.sha
      if (!parentSha) throw new Error('GitHub branch ref has no commit sha.')

      const commitResponse = await fetch(
        githubApi(`/repos/${owner}/${repo}/git/commits/${parentSha}`),
        { headers: readHeaders(), cache: 'no-store' },
      )
      const commitBody = await commitResponse.text()
      if (!commitResponse.ok) {
        throw new Error(`GitHub commit read failed (${commitResponse.status}): ${commitBody}`)
      }
      const commitJson = JSON.parse(commitBody) as { tree?: { sha?: string } }
      const baseTreeSha = commitJson.tree?.sha
      if (!baseTreeSha) throw new Error('GitHub commit has no tree sha.')

      const treeResponse = await fetch(githubApi(`/repos/${owner}/${repo}/git/trees`), {
        method: 'POST',
        headers: writeHeaders(),
        body: JSON.stringify({
          base_tree: baseTreeSha,
          tree: files.map((file, index) => ({
            path: file.path,
            mode: '100644',
            type: 'blob',
            sha: blobShas[index],
          })),
        }),
      })
      const treeBody = await treeResponse.text()
      if (!treeResponse.ok) {
        throw new Error(`GitHub tree create failed (${treeResponse.status}): ${treeBody}`)
      }
      const treeJson = JSON.parse(treeBody) as { sha?: string }
      if (!treeJson.sha) throw new Error('GitHub tree create returned no sha.')

      const newCommitResponse = await fetch(githubApi(`/repos/${owner}/${repo}/git/commits`), {
        method: 'POST',
        headers: writeHeaders(),
        body: JSON.stringify({
          message,
          tree: treeJson.sha,
          parents: [parentSha],
        }),
      })
      const newCommitBody = await newCommitResponse.text()
      if (!newCommitResponse.ok) {
        throw new Error(`GitHub commit create failed (${newCommitResponse.status}): ${newCommitBody}`)
      }
      const newCommitJson = JSON.parse(newCommitBody) as { sha?: string }
      if (!newCommitJson.sha) throw new Error('GitHub commit create returned no sha.')

      const updateRefResponse = await fetch(
        githubApi(`/repos/${owner}/${repo}/git/refs/heads/${branch}`),
        {
          method: 'PATCH',
          headers: writeHeaders(),
          body: JSON.stringify({ sha: newCommitJson.sha }),
        },
      )
      const updateRefBody = await updateRefResponse.text()
      if (updateRefResponse.status === 422 || updateRefResponse.status === 409) {
        const error = new Error(`GitHub ref update conflict (${updateRefResponse.status}): ${updateRefBody}`) as Error & {
          status: number
        }
        error.status = 409
        throw error
      }
      if (!updateRefResponse.ok) {
        throw new Error(`GitHub ref update failed (${updateRefResponse.status}): ${updateRefBody}`)
      }
      return
    } catch (error) {
      lastError = error
      const status = (error as { status?: number }).status
      if (status !== 409) throw error
      await new Promise((resolve) => setTimeout(resolve, 400 * (attempt + 1)))
    }
  }

  throw lastError instanceof Error ? lastError : new Error('GitHub git upload failed after retries.')
}

/** Prefer Contents API for small files; Git Data API for large binaries. */
async function putBinaryFiles(files: GitFilePayload[], message: string) {
  const tooBig = files.find((file) => file.contentBase64.length * 0.75 > GIT_BLOB_MAX_BYTES)
  if (tooBig) {
    const mb = Math.round((tooBig.contentBase64.length * 0.75) / (1024 * 1024))
    throw new Error(`File too large (~${mb}MB). Keep under ~95MB for GitHub upload.`)
  }

  const needsGitApi = files.some(
    (file) => file.contentBase64.length * 0.75 > CONTENTS_API_SAFE_BYTES,
  )
  if (needsGitApi || files.length > 1) {
    await commitFilesViaGitAPI(files, message)
    return
  }

  try {
    await putFileWithRetry(files[0].path, files[0].contentBase64, message)
  } catch (error) {
    const text = error instanceof Error ? error.message : String(error)
    if (/too large to be processed|422/i.test(text)) {
      await commitFilesViaGitAPI(files, message)
      return
    }
    throw error
  }
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

    await putBinaryFiles(
      [
        { path: fullPath, contentBase64: fullContent },
        { path: thumbPath, contentBase64: thumbContent },
      ],
      `Add wallpaper images: ${id}`,
    )

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

/** Upload looping video + JPEG poster/thumb for Live Wallpapers. */
export async function uploadLiveWallpaper(id: string, file: File) {
  try {
    const maxBytes = GIT_BLOB_MAX_BYTES
    if (file.size > maxBytes) {
      throw new Error(
        `Video too large (${Math.round(file.size / (1024 * 1024))}MB). Keep under ~95MB.`,
      )
    }

    const rawExt = file.name.split('.').pop()?.toLowerCase() || 'mp4'
    const extension = ['mp4', 'mov', 'm4v'].includes(rawExt) ? rawExt : 'mp4'
    const fullPath = `wallpapers/${id}/full.${extension}`
    const thumbPath = `wallpapers/${id}/thumb.jpg`

    const thumbBlob = await makeVideoThumbnail(file)
    const fullContent = await fileToBase64(file)
    const thumbContent = await fileToBase64(thumbBlob)

    await putBinaryFiles(
      [
        { path: fullPath, contentBase64: fullContent },
        { path: thumbPath, contentBase64: thumbContent },
      ],
      `Add live wallpaper video: ${id}`,
    )

    const thumbURL = rawUrl(thumbPath)
    return {
      videoURL: rawUrl(fullPath),
      imageURL: thumbURL,
      thumbnailURL: thumbURL,
      fullPath,
      thumbPath,
    }
  } catch (error) {
    throw new Error(humanizeFetchError(error, 'GitHub live upload fail'))
  }
}

const INTRO_RELEASE_TAG = 'intro-assets'
const INTRO_RELEASE_MAX_BYTES = 200 * 1024 * 1024

type GitHubRelease = {
  id: number
  assets?: { id: number; name: string }[]
}

type GitHubReleaseAsset = {
  browser_download_url: string
  name: string
}

async function getOrCreateIntroRelease(): Promise<GitHubRelease> {
  const existing = await fetch(
    githubApi(`/repos/${owner}/${repo}/releases/tags/${INTRO_RELEASE_TAG}`),
    { headers: readHeaders(), cache: 'no-store' },
  )
  if (existing.ok) {
    return (await existing.json()) as GitHubRelease
  }
  if (existing.status !== 404) {
    const body = await existing.text()
    throw new Error(`GitHub release read failed (${existing.status}): ${body}`)
  }

  const created = await fetch(githubApi(`/repos/${owner}/${repo}/releases`), {
    method: 'POST',
    headers: writeHeaders(),
    body: JSON.stringify({
      tag_name: INTRO_RELEASE_TAG,
      name: 'Intro assets',
      body: 'Fullscreen intro media for Wallora Glass (managed by admin panel).',
      draft: false,
      prerelease: true,
    }),
  })
  const body = await created.text()
  if (!created.ok) {
    throw new Error(`GitHub release create failed (${created.status}): ${body}`)
  }
  return JSON.parse(body) as GitHubRelease
}

/** Remove previous intro media so release stays small and URLs stay unique. */
async function deleteAllIntroReleaseAssets(release: GitHubRelease) {
  for (const asset of release.assets ?? []) {
    const name = asset.name.toLowerCase()
    const isIntro =
      name === 'thumb.jpg' ||
      name.startsWith('full.') ||
      name.startsWith('intro-') ||
      name.startsWith('thumb-')
    if (!isIntro) continue
    const response = await fetch(
      githubApi(`/repos/${owner}/${repo}/releases/assets/${asset.id}`),
      { method: 'DELETE', headers: readHeaders() },
    )
    if (!response.ok && response.status !== 404) {
      const body = await response.text()
      throw new Error(`GitHub asset delete failed (${response.status}): ${body}`)
    }
  }
}

async function uploadReleaseAsset(
  releaseId: number,
  blob: Blob,
  name: string,
  contentType: string,
): Promise<GitHubReleaseAsset> {
  const response = await fetch(
    githubUploads(
      `/repos/${owner}/${repo}/releases/${releaseId}/assets?name=${encodeURIComponent(name)}`,
    ),
    {
      method: 'POST',
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${token}`,
        'Content-Type': contentType,
        'X-GitHub-Api-Version': '2022-11-28',
      },
      body: blob,
    },
  )
  const body = await response.text()
  if (!response.ok) {
    throw new Error(`GitHub release upload failed (${response.status}): ${body}`)
  }
  return JSON.parse(body) as GitHubReleaseAsset
}

/**
 * Upload intro video via GitHub Releases (raw binary, supports large files).
 * Contents/Blobs API reject big base64 payloads with 422.
 */
export async function uploadIntroVideo(file: File) {
  try {
    requireToken()
    if (file.size > INTRO_RELEASE_MAX_BYTES) {
      throw new Error(
        `Video too large (${Math.round(file.size / (1024 * 1024))}MB). Keep under ~200MB.`,
      )
    }

    const rawExt = file.name.split('.').pop()?.toLowerCase() || 'mp4'
    const extension = ['mp4', 'mov', 'm4v'].includes(rawExt) ? rawExt : 'mp4'
    // Unique names so iOS disk cache cannot keep serving a replaced full.mp4.
    const stamp = Date.now()
    const videoName = `intro-${stamp}.${extension}`
    const thumbName = `thumb-${stamp}.jpg`
    const contentType =
      file.type ||
      (extension === 'mov' ? 'video/quicktime' : extension === 'm4v' ? 'video/x-m4v' : 'video/mp4')

    const thumbBlob = await makeVideoThumbnail(file)
    const release = await getOrCreateIntroRelease()
    await deleteAllIntroReleaseAssets(release)

    const [videoAsset, thumbAsset] = await Promise.all([
      uploadReleaseAsset(release.id, file, videoName, contentType),
      uploadReleaseAsset(release.id, thumbBlob, thumbName, 'image/jpeg'),
    ])

    return {
      videoURL: videoAsset.browser_download_url,
      imageURL: thumbAsset.browser_download_url,
      fullPath: videoName,
      thumbPath: thumbName,
    }
  } catch (error) {
    throw new Error(humanizeFetchError(error, 'GitHub intro upload fail'))
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

/** Mirror app settings for iOS when Firestore REST is rate-limited. */
export async function pushAppSettingsMirror(settings: {
  adsEnabled: boolean
  adsMode: string
  appOpenAdUnitId: string
  interstitialAdUnitId: string
  interstitialEveryNOpens: number
  interstitialEveryNDownloads: number
  appOpenMinBackgroundSeconds: number
  introEnabled: boolean
  introShowEveryLaunch: boolean
  introVersion: number
  introTitle: string
  introSubtitle: string
  introImageURL: string
  introVideoURL: string
  introMaxSeconds: number
  introButtonTitle: string
  updatedAt: string
}) {
  const content = toBase64Json(settings)
  let lastError: unknown

  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      await putFileWithRetry('settings.json', content, 'Update app settings mirror')
      return
    } catch (error) {
      lastError = error
      const message = error instanceof Error ? error.message : String(error)
      const retryable = /403|429|rate limit|abuse|secondary rate|conflict|409|fetch/i.test(
        message,
      )
      if (!retryable || attempt === 3) break
      await new Promise((resolve) => setTimeout(resolve, 700 * (attempt + 1)))
    }
  }

  throw new Error(humanizeFetchError(lastError, 'GitHub settings mirror fail'))
}
