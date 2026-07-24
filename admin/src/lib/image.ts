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

export function humanizeFetchError(error: unknown, fallback: string): string {
  if (error instanceof TypeError && String(error.message).toLowerCase().includes('fetch')) {
    return 'GitHub network/CORS fail (rate limit wla Brave shields). 3awd ba3da chwiya.'
  }
  if (error instanceof Error) return error.message
  return fallback
}

export function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
