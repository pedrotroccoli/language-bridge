'use client';

import { usePathname, useRouter } from 'next/navigation';
import { ChevronsUpDown } from 'lucide-react';
import { latestVersion } from '@/lib/generated/cli-snippets';

// Add new versions here. `segment` is the folder under content/docs.
const VERSIONS = [
  { label: `Latest (v${latestVersion})`, segment: 'latest' },
] as const;

export function VersionSelect() {
  const pathname = usePathname();
  const router = useRouter();

  const match = pathname.match(/^\/docs\/([^/]+)/);
  const current =
    VERSIONS.find((v) => v.segment === match?.[1])?.segment ?? VERSIONS[0].segment;

  return (
    <label className="relative flex w-full items-center">
      <select
        aria-label="Version"
        value={current}
        onChange={(e) => {
          const segment = e.target.value;
          const rest = pathname.replace(/^\/docs\/[^/]+/, '') || '';
          router.push(`/docs/${segment}${rest}`);
        }}
        className="w-full appearance-none rounded-lg border bg-fd-secondary/50 py-1.5 pl-2.5 pr-7 text-sm font-medium text-fd-secondary-foreground hover:bg-fd-accent focus-visible:outline-none"
      >
        {VERSIONS.map((v) => (
          <option key={v.segment} value={v.segment}>
            {v.label}
          </option>
        ))}
      </select>
      <ChevronsUpDown className="pointer-events-none absolute right-2 size-3.5 text-fd-muted-foreground" />
    </label>
  );
}
