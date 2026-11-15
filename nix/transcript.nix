# `transcript`: verifies or regenerates `nix repl` (*.repl) and shell
# (*.console) transcripts. See transcript.sh. Uses the Nix from the pinned
# nixpkgs, so output matches `nix flake check`.
#
# `nixpkgs` is the flake input (its source), used as `<nixpkgs>` and as the
# nixpkgs of example flakes. `lockFile` is this project's flake.lock: example
# flakes get its nixpkgs entry, so both always pin the same nixpkgs.
{
  pkgs,
  nixpkgs,
  lockFile,
}:
let
  lock = pkgs.lib.importJSON lockFile;
  exampleLock = {
    nodes = {
      nixpkgs = lock.nodes.${lock.nodes.${lock.root}.inputs.nixpkgs};
      root.inputs.nixpkgs = "nixpkgs";
    };
    root = "root";
    inherit (lock) version;
  };
in
pkgs.writeShellApplication {
  name = "transcript";
  runtimeInputs = [
    pkgs.nix
    pkgs.bash
    pkgs.gnused
    pkgs.coreutils
  ];
  text = builtins.readFile ./transcript.sh;
  runtimeEnv = {
    NIX_PATH = "nixpkgs=${nixpkgs}";
    NIXPKGS_SOURCE = "${nixpkgs}";
    FLAKE_LOCK = pkgs.writeText "flake.lock" (builtins.toJSON exampleLock);
  };
}
