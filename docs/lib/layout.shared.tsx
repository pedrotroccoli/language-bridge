import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import Image from 'next/image';
import { appName, gitConfig } from './shared';
import logo from '@/public/logo.png';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      // Logo next to the site name.
      title: (
        <>
          <Image
            src={logo}
            alt=""
            width={24}
            height={24}
            className="rounded-full"
          />
          {appName}
        </>
      ),
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  };
}
