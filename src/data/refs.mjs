// Single source of truth for external links and values that change over time
// (versions, install commands, ...).
//
// Use in any .md/.mdx page as %%key%%: in prose, code blocks, link URLs
// ([text](%%key%%)), and JSX string props. Resolved at build time by
// src/plugins/refs-plugin.mjs (Sätteri mdast plugin); an unknown key fails the build.
// In JS (e.g. astro.config.mjs, MDX expressions), import `refs` directly.
//
// Last verified: 2026-11-15.

const repo = 'https://github.com/alsaghir/nix-mechanics';
const nixosManual = 'https://nixos.org/manual/nixos/stable/';
const nixManual = 'https://nix.dev/manual/nix/stable/';
const nixInstallScript = 'https://nixos.org/nix/install';

export const refs = {
	// This project
	'repo': repo,
	'repo-examples': `${repo}/tree/main/examples`,

	// NixOS
	'nixos-release': '26.05',
	'nixos-download': 'https://nixos.org/download/',
	'nixos-download-iso': 'https://nixos.org/download/#nixos-iso',
	'nixos-manual': nixosManual,
	'nixos-manual-install-graphical': `${nixosManual}#sec-installation-graphical`,
	'nixos-manual-boot-usb': `${nixosManual}#sec-booting-from-usb`,
	'nixos-wsl': 'https://github.com/nix-community/NixOS-WSL',

	// Nix
	'nix-manual': nixManual,
	'nix-manual-uninstall': `${nixManual}installation/uninstall.html`,
	'nix-manual-experimental-features': `${nixManual}development/experimental-features.html`,
	'nix-install-macos-min': '14',
	'nix-install-cmd-linux': `curl --proto '=https' --tlsv1.2 -L ${nixInstallScript} | sh -s -- --daemon`,
	'nix-install-cmd-macos': `curl --proto '=https' --tlsv1.2 -L ${nixInstallScript} | sh`,
};
