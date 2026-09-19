import { createGetUrl } from 'fumadocs-core/source';

export const appName = 'Language Bridge';
export const appDescription =
  'Open-source, self-hosted translation management for i18next. Store keys, let translators fill in values, and serve CDN-cached JSON — on your own infrastructure.';
export const docsRoute = '/docs';
export const docsImageRoute = '/og/docs';
export const siteImageRoute = '/og/image.png';
export const docsContentRoute = '/llms.mdx/docs';

// fill this with your actual GitHub info, for example:
export const gitConfig = {
  user: 'pedrotroccoli',
  repo: 'language-bridge',
  branch: 'main',
};

const getContentUrl = createGetUrl(docsContentRoute);

export function getPageMarkdownUrl(page: { slugs: string[]; locale?: string }) {
  const segments = [...page.slugs, 'content.md'];

  return { segments, url: getContentUrl(segments, page.locale) };
}

const getImageUrl = createGetUrl(docsImageRoute);

export function getPageImageUrl(page: { slugs: string[]; locale?: string }) {
  const segments = [...page.slugs, 'image.png'];

  return { segments, url: getImageUrl(segments, page.locale) };
}
