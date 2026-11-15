# Nix Mechanics

How Nix and NixOS actually work, explained for beginners. Built with Starlight and Mermaid.

## Develop

```sh
direnv allow     # or: nix develop
pnpm install
pnpm dev
```

## Examples

Every Nix snippet shown on the site lives in `examples/`. Each `NAME.nix` has
exactly one expectation next to it: `NAME.expected.nix` (the value it must
evaluate to) or `NAME.expected-error` (lines its error output must contain).
Pages import the files with `?raw`, so the shown code is the tested code.

```sh
nix eval --file examples/basics/let-in.nix   # see what an example evaluates to
nix flake check                              # verify all examples
```

New files must be `git add`ed before `nix flake check` can see them.

## Links and changing values

All external links and values that change over time (versions, install
commands, ...) live in `src/data/refs.mjs`. Pages reference them as `%%key%%`
in prose, code blocks, link URLs (`[text](%%key%%)`), and JSX string props.
An unknown key fails the build.

## License

- Prose, diagrams, images: [CC BY-SA 4.0](LICENSE)
- Code (site source and code snippets): [MIT](LICENSE-CODE)
- Favicon: [NixOS snowflake logo](https://github.com/NixOS/nixos-artwork/tree/master/logo)
  by Simon Frankau and Tim Cuthbertson, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), unmodified
