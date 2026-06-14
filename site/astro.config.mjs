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
        // Transparent-background mark; Starlight swaps it per color scheme.
        light: './src/assets/logo-mark-light.svg',
        dark: './src/assets/logo-mark.svg',
        replacesTitle: false,
      },
      favicon: '/favicon.svg',
      head: [
        // Favicon fallbacks for browsers that don't take the SVG.
        { tag: 'link', attrs: { rel: 'icon', href: '/favicon.ico', sizes: '32x32' } },
        { tag: 'link', attrs: { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' } },
        { tag: 'link', attrs: { rel: 'manifest', href: '/site.webmanifest' } },
        // Browser UI color, per scheme.
        {
          tag: 'meta',
          attrs: { name: 'theme-color', content: '#0a0e14', media: '(prefers-color-scheme: dark)' },
        },
        {
          tag: 'meta',
          attrs: { name: 'theme-color', content: '#ffffff', media: '(prefers-color-scheme: light)' },
        },
        // Social share card (absolute URLs required for OG/Twitter).
        { tag: 'meta', attrs: { property: 'og:image', content: 'https://dvm.eshlox.net/og-image.png' } },
        { tag: 'meta', attrs: { property: 'og:image:width', content: '1200' } },
        { tag: 'meta', attrs: { property: 'og:image:height', content: '630' } },
        { tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
        { tag: 'meta', attrs: { name: 'twitter:image', content: 'https://dvm.eshlox.net/og-image.png' } },
      ],
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/eshlox/dvm',
        },
        {
          icon: 'mastodon',
          label: 'Mastodon',
          href: 'https://fosstodon.org/@eshlox',
        },
        {
          icon: 'x.com',
          label: 'X',
          href: 'https://x.com/eshlox',
        },
        {
          icon: 'blueSky',
          label: 'Bluesky',
          href: 'https://bsky.app/profile/eshlox.net',
        },
      ],
      editLink: {
        baseUrl: 'https://github.com/eshlox/dvm/edit/main/site/',
      },
      components: {
        Footer: './src/components/Footer.astro',
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
            { label: 'Trust tiers & project containers', link: '/docs/reference/projects/' },
            { label: 'Base image', link: '/docs/reference/base/' },
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
