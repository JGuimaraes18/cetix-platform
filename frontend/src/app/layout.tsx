import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'CETIX',
  description: 'CETIX Platform',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
