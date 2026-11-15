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
expectations next to it: `NAME.expected.nix` (the value it must evaluate to),
or one or both of `NAME.expected-error` / `NAME.expected-trace` (lines its
error output must contain in order, without / with `--show-trace`).
Pages import the files with `?raw`, so the shown code is the tested code.

Transcripts replay real sessions in a temporary copy of the file's folder
(its path is printed as `/home/you/example`), ignoring your `nix.conf`, with
`<nixpkgs>` set to the pinned nixpkgs. Output must match exactly:

- `NAME.repl`: `nix repl` sessions (`nix-repl> ` input lines, each followed
  by its output). An optional first line `$ nix repl FLAGS` passes flags
  (e.g. `--debugger`).
- `NAME.console`: shell commands (`$ ` lines, each followed by its output and
  `[exit CODE]`). Commands can run `nix` (with `nix-command` and `flakes`
  enabled), `nix-instantiate`, `nix-env`, `nix-store`, and coreutils against
  a fresh, empty store (no builds or downloads). `nix` gets `--quiet`, which
  matches what a terminal leaves on screen (no progress lines).

Flake examples: a folder with a `flake.nix` gets a `flake.lock` generated
from this project's lock, and the pinned nixpkgs is added to the store, so
the input resolves offline. The input must be exactly
`inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";`. File mtimes
are pinned, so path-flake hashes are stable.

A `.nix` file without expectations is allowed only if a transcript in the
same folder uses it: mentions it (e.g. a `configuration.nix` evaluated there),
or it is the folder's `flake.nix`.

Transcripts that print nixpkgs paths or line numbers (e.g. NixOS errors) must
be regenerated after `nix flake update`; `nix flake check` points them out.

Write only the input lines, then fill in the outputs with `transcript`
(available in the dev shell):

```sh
nix eval --file examples/basics/let-in.nix   # see what an example evaluates to
transcript examples/seeing/user.repl > /tmp/t && mv /tmp/t examples/seeing/user.repl
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
