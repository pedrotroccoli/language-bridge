import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { ImageResponse } from 'next/og';
import { appName, ogImageSize } from './shared';

// Shared 1200x630 social image: logo on the left, title + description on the
// right, brand-orange rule at the bottom. Used by /og/image.png (site default)
// and /og/docs/... (per docs page).
const SIZE = { width: ogImageSize.width, height: ogImageSize.height };
const ORANGE = '#ff7600';

let logoDataUrl: string | undefined;
async function loadLogo() {
  if (!logoDataUrl) {
    const png = await readFile(join(process.cwd(), 'public', 'logo-hero.png'));
    logoDataUrl = `data:image/png;base64,${png.toString('base64')}`;
  }
  return logoDataUrl;
}

// Same faces the app uses: Figtree for headings, Inter for body (both OFL,
// vendored in lib/fonts because ImageResponse needs raw TTF data).
let fonts: { name: string; data: ArrayBuffer; weight: 400 | 700 }[] | undefined;
async function loadFonts() {
  if (!fonts) {
    const dir = join(process.cwd(), 'lib', 'fonts');
    const [figtree, inter] = await Promise.all([
      readFile(join(dir, 'figtree-700.ttf')),
      readFile(join(dir, 'inter-400.ttf')),
    ]);
    fonts = [
      { name: 'Figtree', data: toArrayBuffer(figtree), weight: 700 },
      { name: 'Inter', data: toArrayBuffer(inter), weight: 400 },
    ];
  }
  return fonts;
}

function toArrayBuffer(buf: Buffer): ArrayBuffer {
  return buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) as ArrayBuffer;
}

export async function renderOgImage({
  title,
  description,
}: {
  title: string;
  description?: string;
}) {
  const [logo, fonts] = await Promise.all([loadLogo(), loadFonts()]);

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
          fontFamily: 'Inter',
          borderBottom: `16px solid ${ORANGE}`,
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={logo} alt="" width={300} height={300} style={{ borderRadius: 9999 }} />
        <div style={{ display: 'flex', flexDirection: 'column', flex: 1, gap: 20 }}>
          {title !== appName ? (
            <div style={{ fontFamily: 'Figtree', fontSize: 26, fontWeight: 700, color: ORANGE, letterSpacing: 1 }}>
              {appName}
            </div>
          ) : null}
          <div style={{ fontFamily: 'Figtree', fontSize: 60, fontWeight: 700, lineHeight: 1.1 }}>
            {title}
          </div>
          {description ? (
            <div style={{ fontSize: 28, lineHeight: 1.4, color: '#b0b0b0' }}>{description}</div>
          ) : null}
        </div>
      </div>
    ),
    { ...SIZE, fonts },
  );
}
