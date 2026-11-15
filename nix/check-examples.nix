# Verifies documentation examples. Every `examples/**/NAME.nix` must have
# exactly one expectation next to it:
#
#   NAME.expected.nix  The value `nix eval --file NAME.nix` prints (formatting
#                      may differ). Checked by importing both and comparing.
#   NAME.expected-error  Lines that must appear in the error output of
#                      `nix eval --file NAME.nix`, which must fail. Checked by
#                      running `nix eval` inside the build sandbox.
#
# Returns an attrset of checks for the flake's `checks.<system>`.
{ pkgs, root }:
let
  inherit (pkgs) lib;

  rel = path: lib.removePrefix "${toString root}/" (toString path);
  files = lib.filesystem.listFilesRecursive root;

  valueSuffix = ".expected.nix";
  errorSuffix = ".expected-error";

  examples = lib.filter (p: lib.hasSuffix ".nix" p && !lib.hasSuffix valueSuffix p) files;
  sibling = example: suffix: dirOf example + "/${lib.removeSuffix ".nix" (baseNameOf example)}${suffix}";
  has = example: suffix: lib.pathExists (sibling example suffix);

  valueExamples = lib.filter (e: has e valueSuffix) examples;
  errorExamples = lib.filter (e: has e errorSuffix) examples;

  # Every example has exactly one expectation: no unverified examples.
  badExpectations = lib.filter (e: has e valueSuffix == has e errorSuffix) examples;
  expectationsOk =
    if examples == [ ] then
      throw "check-examples: no examples found under ${toString root}"
    else if badExpectations != [ ] then
      throw (
        "check-examples: each example needs exactly one of ${valueSuffix} or ${errorSuffix}:\n"
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
    lib.optional (actual != expected) "${rel e}\n  expected: ${pretty expected}\n  actual:   ${pretty actual}"
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
  emptyErrorFiles = lib.filter (
    e: lib.trim (builtins.readFile (sibling e errorSuffix)) == ""
  ) errorExamples;

  errors =
    assert expectationsOk;
    if emptyErrorFiles != [ ] then
      throw (
        "check-examples: empty ${errorSuffix} file(s):\n"
        + lib.concatMapStringsSep "\n" (e: "  ${rel (sibling e errorSuffix)}") emptyErrorFiles
      )
    else
      pkgs.runCommand "examples-errors" { nativeBuildInputs = [ pkgs.nix ]; } ''
        export HOME=$TMPDIR NIX_CONF_DIR=$TMPDIR/etc NIX_STATE_DIR=$TMPDIR/state NIX_LOG_DIR=$TMPDIR/log
        failed=0

        check() {
          local name=$1 example=$2 expected=$3
          if nix --extra-experimental-features nix-command --store dummy:// \
               eval --file "$example" > stdout 2> stderr; then
            echo "FAIL $name: expected an error, but it evaluated to: $(cat stdout)"
            failed=1
            return
          fi
          while IFS= read -r line; do
            [ -z "$line" ] && continue
            if ! grep -qF -- "$line" stderr; then
              echo "FAIL $name: error output is missing: $line"
              echo "--- actual error output:"
              cat stderr
              failed=1
            fi
          done < "$expected"
        }

        ${lib.concatMapStrings (e: ''
          check ${lib.escapeShellArg (rel e)} ${root}/${lib.escapeShellArg (rel e)} ${root}/${lib.escapeShellArg (rel (sibling e errorSuffix))}
        '') errorExamples}

        [ "$failed" = 0 ] || exit 1
        echo "${toString (lib.length errorExamples)} error example(s) OK" > $out
      '';
in
{
  examples-values = values;
  examples-errors = errors;
}
