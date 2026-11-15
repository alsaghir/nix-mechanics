# Usage: transcript FILE.repl|FILE.console
#
# Replays a transcript and prints it regenerated from the real output. Diff it
# against the file to verify it, or redirect it to the file to (re)generate the
# outputs. Relative paths resolve from the transcript's folder (see below).
#
#   FILE.repl     `nix-repl> INPUT` lines, each followed by its output, all in
#                 one `nix repl` session. An optional first line
#                 `$ nix repl FLAGS...` starts the REPL with FLAGS.
#   FILE.console  `$ COMMAND` lines, each followed by its output (stdout and
#                 stderr) and `[exit CODE]`. Each command runs in bash.
#
# Both ignore system and user nix.conf, so output is the same everywhere
# (enabled features change what Nix prints, e.g. the debugger's :env). They
# enable `nix-command` and `flakes`, as readers do after "Start here", and
# `<nixpkgs>` is the pinned nixpkgs (NIX_PATH is set by transcript.nix). Each
# run gets a fresh, empty store of its own, so commands can add paths and
# create profiles, but can't build or download anything.
#
# Flakes: if the folder has a flake.nix, its flake.lock is written from this
# project's lock (FLAKE_LOCK, set by transcript.nix) and the pinned nixpkgs
# source is added to the store, so `github:NixOS/nixpkgs/nixos-unstable`
# resolves without network. The input must be named `nixpkgs` and use exactly
# that URL, otherwise Nix tries to re-lock and fails offline.
#
# Commands run in a temporary copy of the transcript's folder, so they can
# create files. Its path differs on every run, so it is printed as
# /home/you/example.

placeholder=/home/you/example
file=$(realpath "$1")

tmp=$(realpath "$(mktemp -d)")
# Store paths are read-only; make them writable so they can be removed.
trap 'chmod -R u+w "$tmp"; rm -rf "$tmp"' EXIT
work="$tmp/example"
cp -r "$(dirname "$file")" "$work"
chmod -R u+w "$work"
cd "$work"
# Transcripts aren't part of the example; a flake's narHash would otherwise
# depend on the transcript's own content.
rm -f ./*.console ./*.repl

export NIX_CONF_DIR="$tmp" NIX_USER_CONF_FILES="$tmp/nix.conf"
export XDG_CACHE_HOME="$tmp/cache" TZ=UTC
export NIX_CONFIG=$'extra-experimental-features = nix-command flakes\nstore = local?root='"$tmp/root"

if [ -f flake.nix ]; then
  cp "$FLAKE_LOCK" flake.lock && chmod u+w flake.lock
  nix store add --name source "$NIXPKGS_SOURCE" > /dev/null
fi

# A path flake's lastModified (and so its narHash) comes from file mtimes; pin
# them as the Nix store does.
find . -exec touch -h -d @1 {} +

strip_colors() { sed 's/\x1b\[[0-9;]*m//g'; }
show_placeholder() { sed "s|${work//./\\.}|$placeholder|g"; }

# The build sandbox has no network, so `nix` warns about it (src/nix/main.cc).
# Only `--offline` silences it, which readers don't type, so drop that line.
drop_offline_warning() {
  grep -vxF "warning: you don't have Internet access; disabling some network-dependent features" || true
}

repl() {
  local marker='"@@nix-mechanics-marker@@"' header flags=() inputs=() segments=()
  local current="" seen=-1 line i output
  mapfile -t inputs < <(sed -n 's/^nix-repl> //p' "$file")

  header=$(head -n 1 "$file")
  if [[ "$header" =~ ^\$\ nix\ repl(\ |$) ]]; then
    read -ra flags <<< "${header#\$ nix repl}"
  else
    header=""
  fi

  # A marker expression after each input splits the output per input.
  {
    echo "$marker"
    for line in "${inputs[@]}"; do printf '%s\n%s\n' "$line" "$marker"; done
  } | nix repl "${flags[@]}" 2>&1 | strip_colors | show_placeholder > "$tmp/raw"

  while IFS= read -r line; do
    if [ "$line" = "$marker" ]; then
      if [ "$seen" -ge 0 ]; then segments+=("$current"); fi
      current=""
      seen=$((seen + 1))
    elif [ "$seen" -ge 0 ]; then
      current+="$line"$'\n'
    fi
  done < "$tmp/raw"

  if [ -n "$header" ]; then printf '%s\n' "$header"; fi
  for i in "${!inputs[@]}"; do
    if [ "$i" -gt 0 ]; then echo; fi
    printf 'nix-repl> %s\n' "${inputs[$i]}"
    # Drop leading blank lines; $(...) drops trailing ones.
    output=$(printf '%s' "${segments[$i]:-}" | sed '/./,$!d')
    if [ -n "$output" ]; then printf '%s\n' "$output"; fi
  done
}

console() {
  local commands=() i status
  mapfile -t commands < <(sed -n 's/^\$ //p' "$file")
  # On a terminal `nix` logs at level notice and shows progress (e.g.
  # "evaluating …") in a bar that disappears; elsewhere it logs at info and
  # prints that progress as lines (src/nix/main.cc). --quiet is info minus one,
  # so output matches what stays on a reader's screen. Legacy nix-* commands
  # don't do this.
  mkdir -p "$tmp/bin"
  printf '#!%s\nexec %q --quiet "$@"\n' "$BASH" "$(command -v nix)" > "$tmp/bin/nix"
  chmod +x "$tmp/bin/nix"
  for i in "${!commands[@]}"; do
    if [ "$i" -gt 0 ]; then echo; fi
    printf '$ %s\n' "${commands[$i]}"
    status=0
    PATH="$tmp/bin:$PATH" bash -c "${commands[$i]}" > "$tmp/out" 2>&1 < /dev/null || status=$?
    strip_colors < "$tmp/out" | drop_offline_warning | show_placeholder > "$tmp/clean"
    cat "$tmp/clean"
    # Output without a final newline (e.g. `nix eval --raw`) gets one here.
    if [ -s "$tmp/clean" ] && [ -n "$(tail -c 1 "$tmp/clean")" ]; then echo; fi
    printf '[exit %d]\n' "$status"
  done
}

case "$file" in
  *.repl) repl ;;
  *.console) console ;;
  *) echo "transcript: expected a .repl or .console file: $1" >&2; exit 2 ;;
esac
