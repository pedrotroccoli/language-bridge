import Image from 'next/image';
import Link from 'next/link';
import { appName, gitConfig } from '@/lib/shared';
import logoHero from '@/public/logo-hero.png';

export default function HomePage() {
  return (
    <div className="flex flex-col flex-1 items-center justify-center gap-6 px-4 py-16 text-center">
      <Image
        src={logoHero}
        alt={appName}
        width={200}
        height={200}
        priority
        className="rounded-full"
      />
      <h1 className="text-4xl font-bold tracking-tight">{appName}</h1>
      <p className="max-w-xl text-lg text-fd-muted-foreground">
        Open-source, self-hosted translation management for i18next. Store keys,
        let translators fill in values, and serve CDN-cached JSON — on your own
        infrastructure.
      </p>
      <div className="flex flex-wrap items-center justify-center gap-3">
        <Link
          href="/docs"
          className="rounded-lg bg-fd-primary px-4 py-2 text-sm font-medium text-fd-primary-foreground hover:bg-fd-primary/90"
        >
          Read the docs
        </Link>
        <a
          href={`https://github.com/${gitConfig.user}/${gitConfig.repo}`}
          className="rounded-lg border px-4 py-2 text-sm font-medium hover:bg-fd-accent"
        >
          GitHub
        </a>
      </div>
    </div>
  );
}
