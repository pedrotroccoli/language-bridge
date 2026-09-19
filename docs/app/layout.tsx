import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { Provider } from '@/components/provider';
import { appDescription, appName, siteImageRoute } from '@/lib/shared';
import './global.css';

const inter = Inter({
  subsets: ['latin'],
});

// Site-wide defaults. Docs pages override title/description/og:image per page
// via generateMetadata; everything else (home, 404) inherits these.
export const metadata: Metadata = {
  // Every page title gets the site name appended; pages without one fall back to it.
  title: { template: `%s | ${appName}`, default: appName },
  description: appDescription,
  // Absolute base for OG/Twitter image URLs. On GitHub Pages the site lives under
  // the /language-bridge repo subpath; locally it's the dev origin.
  metadataBase: new URL(
    process.env.GITHUB_PAGES === 'true'
      ? 'https://pedrotroccoli.github.io/language-bridge'
      : 'http://localhost:3000',
  ),
  openGraph: {
    type: 'website',
    siteName: appName,
    title: appName,
    description: appDescription,
    images: siteImageRoute,
  },
  twitter: {
    card: 'summary_large_image',
    title: appName,
    description: appDescription,
    images: siteImageRoute,
  },
};

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className={inter.className} suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <Provider>{children}</Provider>
      </body>
    </html>
  );
}
