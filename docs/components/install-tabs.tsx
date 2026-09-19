import { Tab, Tabs } from 'fumadocs-ui/components/tabs';
import { DynamicCodeBlock } from 'fumadocs-ui/components/dynamic-codeblock';

// Package-manager install tabs. Usage in MDX:
//   <InstallTabs pkg="@language-bridge/cli" dev />
const MANAGERS = [
  { value: 'npm', build: (pkg: string, dev: boolean) => `npm i ${dev ? '-D ' : ''}${pkg}` },
  { value: 'pnpm', build: (pkg: string, dev: boolean) => `pnpm add ${dev ? '-D ' : ''}${pkg}` },
  { value: 'yarn', build: (pkg: string, dev: boolean) => `yarn add ${dev ? '-D ' : ''}${pkg}` },
  { value: 'bun', build: (pkg: string, dev: boolean) => `bun add ${dev ? '-d ' : ''}${pkg}` },
];

export function InstallTabs({ pkg, dev = false }: { pkg: string; dev?: boolean }) {
  return (
    <Tabs items={MANAGERS.map((m) => m.value)}>
      {MANAGERS.map((m) => (
        <Tab key={m.value} value={m.value}>
          <DynamicCodeBlock lang="bash" code={m.build(pkg, dev)} />
        </Tab>
      ))}
    </Tabs>
  );
}
