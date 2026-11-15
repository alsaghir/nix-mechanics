// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import mermaid from 'astro-mermaid';
import { satteri } from '@astrojs/markdown-satteri';
import { refs } from './src/data/refs.mjs';
import { refsPlugin } from './src/plugins/refs-plugin.mjs';

export default defineConfig({
	markdown: {
		processor: satteri({ mdastPlugins: [refsPlugin] }),
	},
	integrations: [
		// Must come before starlight so ```mermaid blocks are transformed first.
		mermaid({ autoTheme: true }),
		starlight({
			title: 'Nix Mechanics',
			social: [{ icon: 'github', label: 'GitHub', href: refs['repo'] }],
			sidebar: [
				{
					label: 'Foundations',
					items: [
						{ label: 'Start here', slug: 'start-here' },
						{ label: 'Seeing what Nix sees', slug: 'seeing-what-nix-sees' },
						{ label: 'Reading errors and tracing', slug: 'reading-errors' },
					],
				},
				{
					label: 'Nix on another distro / WSL',
					items: [{ label: 'Overview', slug: 'other-distro' }],
				},
				{
					label: 'NixOS',
					items: [
						{ label: 'Overview', slug: 'nixos' },
						{ label: 'Changing your system, and undoing it', slug: 'nixos/changing-your-system' },
					],
				},
				{
					label: 'About',
					items: [{ autogenerate: { directory: 'about' } }],
				},
			],
		}),
	],
});
