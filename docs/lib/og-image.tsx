import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { ImageResponse } from 'next/og';
import { appName } from './shared';

// Shared 1200x630 social image: logo on the left, title + description on the
// right, brand-orange rule at the bottom. Used by /og/image.png (site default)
// and /og/docs/... (per docs page).
const SIZE = { width: 1200, height: 630 };
const ORANGE = '#ff7600';

let logoDataUrl: string | undefined;
async function loadLogo() {
  if (!logoDataUrl) {
    const png = await readFile(join(process.cwd(), 'public', 'logo-hero.png'));
    logoDataUrl = `data:image/png;base64,${png.toString('base64')}`;
  }
  return logoDataUrl;
}

export async function renderOgImage({
  title,
  description,
}: {
  title: string;
  description?: string;
}) {
  const logo = await loadLogo();

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          gap: 64,
          padding: '0 96px',
          background: '#0f0f0f',
          color: '#f5f5f5',
          fontFamily: 'sans-serif',
          borderBottom: `16px solid ${ORANGE}`,
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={logo} alt="" width={300} height={300} style={{ borderRadius: 9999 }} />
        <div style={{ display: 'flex', flexDirection: 'column', flex: 1, gap: 20 }}>
          {title !== appName ? (
            <div style={{ fontSize: 26, fontWeight: 600, color: ORANGE, letterSpacing: 1 }}>
              {appName}
            </div>
          ) : null}
          <div style={{ fontSize: 60, fontWeight: 700, lineHeight: 1.1 }}>{title}</div>
          {description ? (
            <div style={{ fontSize: 28, lineHeight: 1.4, color: '#b0b0b0' }}>{description}</div>
          ) : null}
        </div>
      </div>
    ),
    SIZE,
  );
}
