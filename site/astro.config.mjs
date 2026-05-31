// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
  site: 'https://dvm.eshlox.net',
  integrations: [
    starlight({
      title: 'DVM',
      description:
        'Disposable development VMs. A small Bash wrapper around Lima that keeps host files out of the guest.',
      logo: {
        src: './src/assets/logo.svg',
        replacesTitle: false,
      },
      favicon: '/favicon.svg',
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/eshlox/dvm',
        },
      ],
      editLink: {
        baseUrl: 'https://github.com/eshlox/dvm/edit/main/site/',
      },
      customCss: ['./src/styles/theme.css'],
      // Docs live under /docs/* (content nested in src/content/docs/docs/).
      // The site root "/" is served by src/pages/index.astro (the landing page).
      sidebar: [
        {
          label: 'Getting started',
          items: [
            { label: 'Install', link: '/docs/getting-started/install/' },
            { label: 'Quickstart', link: '/docs/getting-started/quickstart/' },
          ],
        },
        {
          label: 'Reference',
          items: [
            { label: 'Commands', link: '/docs/reference/commands/' },
            { label: 'Config & setup scripts', link: '/docs/reference/config/' },
            { label: 'Lima behavior', link: '/docs/reference/lima/' },
          ],
        },
        {
          label: 'Guides',
          items: [
            { label: 'Security model', link: '/docs/guides/security/' },
            { label: 'Troubleshooting', link: '/docs/guides/troubleshooting/' },
          ],
        },
        {
          label: 'Examples',
          items: [{ autogenerate: { directory: 'docs/examples' } }],
        },
      ],
    }),
  ],
});
