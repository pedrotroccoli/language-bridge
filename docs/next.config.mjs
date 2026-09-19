import { createMDX } from 'fumadocs-mdx/next';

const withMDX = createMDX();

// On GitHub Pages the site is served from a repo subpath
// (https://pedrotroccoli.github.io/language-bridge). Set GITHUB_PAGES=true when
// building for Pages so links/assets are prefixed; local dev stays at /docs.
const isPages = process.env.GITHUB_PAGES === 'true';
const basePath = isPages ? '/language-bridge' : undefined;

/** @type {import('next').NextConfig} */
const config = {
  output: 'export',
  reactStrictMode: true,
  basePath,
  assetPrefix: basePath,
  images: { unoptimized: true },
};

export default withMDX(config);
