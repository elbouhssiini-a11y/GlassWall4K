/** Build a smaller JPEG thumb for GitHub (full image stays original). */
export async function makeThumbnail(file: File, maxEdge = 720, quality = 0.72): Promise<Blob> {
  const bitmap = await createImageBitmap(file)
  try {
    const scale = Math.min(1, maxEdge / Math.max(bitmap.width, bitmap.height))
    const width = Math.max(1, Math.round(bitmap.width * scale))
    const height = Math.max(1, Math.round(bitmap.height * scale))
    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height
    const ctx = canvas.getContext('2d')
    if (!ctx) throw new Error('Canvas unavailable')
    ctx.drawImage(bitmap, 0, 0, width, height)

    const blob = await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob(
        (result) => (result ? resolve(result) : reject(new Error('Thumb encode fail'))),
        'image/jpeg',
        quality,
      )
    })
    return blob
  } finally {
    bitmap.close()
  }
}

/** Grab a frame from a video file for the Live Wallpapers thumb. */
export async function makeVideoThumbnail(
  file: File,
  maxEdge = 720,
  quality = 0.72,
): Promise<Blob> {
  const objectUrl = URL.createObjectURL(file)
  try {
    const video = document.createElement('video')
    video.muted = true
    video.defaultMuted = true
    video.playsInline = true
    video.setAttribute('playsinline', 'true')
    video.preload = 'auto'
    video.src = objectUrl

    await new Promise<void>((resolve, reject) => {
      const fail = () => reject(new Error('Video load fail for thumbnail'))
      video.onloadedmetadata = () => resolve()
      video.onerror = fail
      // Safari sometimes needs an explicit load().
      video.load()
    })

    // Nudge decode so canvas can paint a frame (esp. Safari / MOV).
    try {
      await video.play()
      video.pause()
    } catch {
      // Autoplay policies — muted should usually work; ignore if blocked.
    }

    const seekTo =
      Number.isFinite(video.duration) && video.duration > 0
        ? Math.min(0.25, video.duration * 0.1)
        : 0
    if (Math.abs(video.currentTime - seekTo) > 0.01) {
      video.currentTime = seekTo
      await new Promise<void>((resolve, reject) => {
        const fail = () => reject(new Error('Video seek fail for thumbnail'))
        video.onseeked = () => resolve()
        video.onerror = fail
      })
    }

    const sourceW = video.videoWidth || 720
    const sourceH = video.videoHeight || 1280
    const scale = Math.min(1, maxEdge / Math.max(sourceW, sourceH))
    const width = Math.max(1, Math.round(sourceW * scale))
    const height = Math.max(1, Math.round(sourceH * scale))
    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height
    const ctx = canvas.getContext('2d')
    if (!ctx) throw new Error('Canvas unavailable')
    ctx.drawImage(video, 0, 0, width, height)

    return await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob(
        (result) => (result ? resolve(result) : reject(new Error('Video thumb encode fail'))),
        'image/jpeg',
        quality,
      )
    })
  } finally {
    URL.revokeObjectURL(objectUrl)
  }
}

export function humanizeFetchError(error: unknown, fallback: string): string {
  if (error instanceof TypeError && String(error.message).toLowerCase().includes('fetch')) {
    return 'GitHub network fail. Restart Vite (proxy) w jarrab Publish to app.'
  }
  if (error instanceof Error) {
    if (/403|429|rate limit|abuse|secondary rate/i.test(error.message)) {
      return 'GitHub rate limit. Stanna 1 min, then Publish to app.'
    }
    return error.message
  }
  return fallback
}

export function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
