import { source } from '@/lib/source';
import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import { FullSearchTrigger } from 'fumadocs-ui/layouts/shared/slots/search-trigger';
import { baseOptions } from '@/lib/layout.shared';
import { VersionSelect } from '@/components/version-select';

export default function Layout({ children }: LayoutProps<'/docs'>) {
  return (
    <DocsLayout
      tree={source.getPageTree()}
      // Version select sits directly above the search box, in the sidebar.
      searchToggle={{ enabled: false }}
      sidebar={{
        banner: (
          <div className="flex flex-col gap-2">
            <VersionSelect />
            <FullSearchTrigger className="w-full" />
          </div>
        ),
      }}
      {...baseOptions()}
    >
      {children}
    </DocsLayout>
  );
}
