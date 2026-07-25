import { useEffect } from 'react'

export type StatusTone = 'ok' | 'off' | 'busy'

export type PageStatus = {
  tone: StatusTone
  label: string
  title?: string
}

type Props = {
  tone: StatusTone
  label: string
  title?: string
  className?: string
}

export function StatusBadge({ tone, label, title, className }: Props) {
  return (
    <div
      className={`status-badge status-badge--${tone}${className ? ` ${className}` : ''}`}
      role="status"
      aria-live="polite"
      title={title}
    >
      <span className="status-badge__dot" aria-hidden="true" />
      {label}
    </div>
  )
}

/** Push live status up to the page header (top-right). */
export function usePageStatus(
  status: PageStatus,
  onStatusChange?: (status: PageStatus | null) => void,
) {
  useEffect(() => {
    onStatusChange?.(status)
  }, [status.tone, status.label, status.title, onStatusChange])

  useEffect(() => {
    return () => onStatusChange?.(null)
  }, [onStatusChange])
}
