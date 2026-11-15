{
  description = "Nix Mechanics — how Nix and NixOS actually work, explained !";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      checks = forAllSystems (
        pkgs:
        import ./nix/check-examples.nix {
          inherit pkgs;
          root = ./examples;
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "nix-mechanics-devshell";

          packages = with pkgs; [
            nodejs_26
            pnpm
            git
            curl
            jq
          ];

          shellHook = ''
            export PATH="$PWD/node_modules/.bin:$PATH"
            echo "✅ Nix Mechanics dev shell ready (node $(node --version))"
          '';
        };
      });
    };
}
