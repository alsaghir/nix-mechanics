// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import mermaid from 'astro-mermaid';

export default defineConfig({
	integrations: [
		// Must come before starlight so ```mermaid blocks are transformed first.
		mermaid({ autoTheme: true }),
		starlight({
			title: 'Nix Mechanics',
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/alsaghir/nix-mechanics' }],
			sidebar: [
				{
					label: 'Guides',
					items: [{ label: 'Example Guide', slug: 'guides/example' }],
				},
				{
					label: 'Reference',
					items: [{ autogenerate: { directory: 'reference' } }],
				},
			],
		}),
	],
});
