import { generateOGImage } from 'fumadocs-ui/og';
import { appDescription, appName } from '@/lib/shared';

// Default og:image for routes without their own (home, 404). The `.png` route
// segment matters: GitHub Pages picks Content-Type from the file extension.
// Docs pages get a per-page image from app/og/docs instead.
export const revalidate = false;

export function GET() {
  return generateOGImage({
    title: appName,
    description: appDescription,
    site: appName,
    width: 1200,
    height: 630,
  });
}
