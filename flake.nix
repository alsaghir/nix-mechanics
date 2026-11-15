{
  description = "Nix Mechanics — how Nix and NixOS actually work, explained !";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      # The only system the examples are run and checked on.
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      formatter.${system} = pkgs.nixfmt-tree;

      checks.${system} = import ./nix/check-examples.nix {
        inherit pkgs nixpkgs;
        lockFile = ./flake.lock;
        root = ./examples;
      };

      devShells.${system} = {
        default = pkgs.mkShell {
          name = "nix-mechanics-devshell";

          packages = with pkgs; [
            nodejs_26
            pnpm
            git
            curl
            jq
            (import ./nix/transcript.nix {
              inherit pkgs nixpkgs;
              lockFile = ./flake.lock;
            })
          ];

          shellHook = ''
            export PATH="$PWD/node_modules/.bin:$PATH"
            echo "✅ Nix Mechanics dev shell ready (node $(node --version))" >&2
          '';
        };
      };
    };
}
