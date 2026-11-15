# Verifies documentation examples. Every `examples/**/NAME.nix` must have
# expectations next to it: either a value, or one or both error kinds. A file
# without expectations must be used by a transcript in its folder.
#
#   NAME.expected.nix    The value `nix eval --file NAME.nix` prints
#                        (formatting may differ). Checked by importing both
#                        and comparing.
#   NAME.expected-error  Lines that must appear, in this order, in the error
#                        output of `nix eval --file NAME.nix`, which must fail.
#   NAME.expected-trace  The same for `nix eval --show-trace --file NAME.nix`.
#
# Error kinds run `nix eval` inside the build sandbox.
#
# Plus transcripts, `examples/**/NAME.repl` (`nix repl` sessions) and
# `NAME.console` (shell commands with output and exit code), replayed for real;
# see transcript.sh. Regenerate the outputs with `transcript FILE`.
#
# Returns an attrset of checks for the flake's `checks.<system>`.
{
  pkgs,
  nixpkgs,
  lockFile,
  root,
}:
let
  inherit (pkgs) lib;

  rel = path: lib.removePrefix "${toString root}/" (toString path);
  files = lib.filesystem.listFilesRecursive root;

  valueSuffix = ".expected.nix";
  # Error expectation suffix -> extra `nix eval` flags.
  errorKinds = {
    ".expected-error" = "";
    ".expected-trace" = "--show-trace";
  };
  errorSuffixes = lib.attrNames errorKinds;

  examples = lib.filter (p: lib.hasSuffix ".nix" p && !lib.hasSuffix valueSuffix p) files;
  sibling =
    example: suffix: dirOf example + "/${lib.removeSuffix ".nix" (baseNameOf example)}${suffix}";
  has = example: suffix: lib.pathExists (sibling example suffix);
  hasError = example: lib.any (has example) errorSuffixes;

  valueExamples = lib.filter (e: has e valueSuffix) examples;
  # One entry per (example, error expectation) pair.
  errorChecks = lib.concatMap (
    e:
    map (suffix: {
      example = e;
      expectation = sibling e suffix;
      flags = errorKinds.${suffix};
    }) (lib.filter (has e) errorSuffixes)
  ) examples;

  # A value or error expectation, never both. Neither is allowed only for files
  # a transcript in the same folder uses: ones it mentions (e.g. a NixOS
  # configuration.nix evaluated there), and flake.nix (`.#…` refers to it).
  # No unverified examples.
  usedByTranscript =
    e:
    lib.any (
      t:
      dirOf t == dirOf e
      && (baseNameOf e == "flake.nix" || lib.hasInfix (baseNameOf e) (builtins.readFile t))
    ) transcripts;
  badExpectations = lib.filter (
    e: if has e valueSuffix then hasError e else !hasError e && !usedByTranscript e
  ) examples;
  expectationsOk =
    if examples == [ ] then
      throw "check-examples: no examples found under ${toString root}"
    else if badExpectations != [ ] then
      throw (
        "check-examples: each example needs either ${valueSuffix} or error expectations (${lib.concatStringsSep ", " errorSuffixes}), or must be used by a transcript in its folder:\n"
        + lib.concatMapStringsSep "\n" (e: "  ${rel e}") badExpectations
      )
    else
      true;

  # Value examples: compared at evaluation time.
  pretty = lib.generators.toPretty { };
  valueFailures = lib.concatMap (
    e:
    let
      actual = import e;
      expected = import (sibling e valueSuffix);
    in
    lib.optional (
      actual != expected
    ) "${rel e}\n  expected: ${pretty expected}\n  actual:   ${pretty actual}"
  ) valueExamples;

  values =
    assert expectationsOk;
    if valueFailures != [ ] then
      throw (
        "check-examples: ${toString (lib.length valueFailures)} value example(s) failed:\n"
        + lib.concatStringsSep "\n" valueFailures
      )
    else
      pkgs.runCommand "examples-values" { } ''
        echo "${toString (lib.length valueExamples)} value example(s) OK" > $out
      '';

  # Error examples: `nix eval` runs in the sandbox with a dummy store, since
  # evaluating plain values needs no store access.
  emptyErrorFiles = lib.filter (c: lib.trim (builtins.readFile c.expectation) == "") errorChecks;

  errors =
    assert expectationsOk;
    if emptyErrorFiles != [ ] then
      throw (
        "check-examples: empty error expectation file(s):\n"
        + lib.concatMapStringsSep "\n" (c: "  ${rel c.expectation}") emptyErrorFiles
      )
    else
      pkgs.runCommand "examples-errors" { nativeBuildInputs = [ pkgs.nix ]; } ''
        export HOME=$TMPDIR NIX_CONF_DIR=$TMPDIR/etc NIX_STATE_DIR=$TMPDIR/state NIX_LOG_DIR=$TMPDIR/log
        failed=0

        # check NAME EXAMPLE EXPECTATION [FLAGS...]
        check() {
          local name=$1 example=$2 expected=$3 pos=0 n
          shift 3
          if nix --extra-experimental-features nix-command --store dummy:// \
               eval "$@" --file "$example" > stdout 2> stderr; then
            echo "FAIL $name: expected an error, but it evaluated to: $(cat stdout)"
            failed=1
            return
          fi
          # Each expected line must appear after the previous one.
          while IFS= read -r line; do
            [ -z "$line" ] && continue
            n=$(tail -n "+$((pos + 1))" stderr | grep -nF -m 1 -- "$line" | cut -d: -f1 || true)
            if [ -z "$n" ]; then
              echo "FAIL $name: error output is missing (in this order): $line"
              echo "--- actual error output:"
              cat stderr
              failed=1
              return
            fi
            pos=$((pos + n))
          done < "$expected"
        }

        ${lib.concatMapStrings (c: ''
          check ${lib.escapeShellArg (rel c.expectation)} ${root}/${lib.escapeShellArg (rel c.example)} ${root}/${lib.escapeShellArg (rel c.expectation)} ${c.flags}
        '') errorChecks}

        [ "$failed" = 0 ] || exit 1
        echo "${toString (lib.length errorChecks)} error expectation(s) OK" > $out
      '';

  # Transcripts (*.repl, *.console): replayed for real; output must match exactly.
  transcripts = lib.filter (p: lib.hasSuffix ".repl" p || lib.hasSuffix ".console" p) files;
  transcriptTool = import ./transcript.nix { inherit pkgs nixpkgs lockFile; };

  transcriptsCheck =
    pkgs.runCommand "examples-transcripts"
      {
        nativeBuildInputs = [
          transcriptTool
          pkgs.diffutils
        ];
      }
      ''
        export HOME=$TMPDIR NIX_STATE_DIR=$TMPDIR/state NIX_LOG_DIR=$TMPDIR/log
        failed=0
        ${lib.concatMapStrings (t: ''
          if ! transcript ${root}/${lib.escapeShellArg (rel t)} | diff -u ${root}/${lib.escapeShellArg (rel t)} - ; then
            echo "FAIL ${rel t}: transcript differs from the real output (+ = actual)"
            failed=1
          fi
        '') transcripts}
        [ "$failed" = 0 ] || exit 1
        echo "${toString (lib.length transcripts)} transcript(s) OK" > $out
      '';
in
{
  examples-values = values;
  examples-errors = errors;
  examples-transcripts = transcriptsCheck;
}
