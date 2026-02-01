import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Fresh Next.js App',
  description: 'A greenfield Next.js project for SDLC wizard testing',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
