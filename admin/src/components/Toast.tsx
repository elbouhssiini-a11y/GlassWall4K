import { useEffect, useRef, useState } from 'react'

export type ToastVariant = 'ok' | 'loading' | 'error'

type ToastState = {
  message: string
  variant: ToastVariant
}

type Options = {
  /** Auto-hide for ok toasts. Default 1800ms. loading/error stay until replaced. */
  okDismissMs?: number
}

export function useToast(options: Options = {}) {
  const okDismissMs = options.okDismissMs ?? 1800
  const [toast, setToast] = useState<ToastState | null>(null)
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current)
    }
  }, [])

  function clear() {
    if (timerRef.current) clearTimeout(timerRef.current)
    timerRef.current = null
    setToast(null)
  }

  function show(message: string, variant: ToastVariant = 'ok') {
    if (timerRef.current) clearTimeout(timerRef.current)
    setToast({ message, variant })

    if (variant === 'ok') {
      timerRef.current = setTimeout(() => {
        setToast((current) =>
          current?.message === message && current.variant === 'ok' ? null : current,
        )
      }, okDismissMs)
    }
  }

  return { toast, show, clear }
}

export function Toast({
  message,
  variant = 'ok',
}: {
  message: string
  variant?: ToastVariant
}) {
  return (
    <p className={`toast-notice toast-notice--${variant}`} role="status">
      {message}
    </p>
  )
}
