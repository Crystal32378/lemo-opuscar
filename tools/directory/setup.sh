#!/bin/sh
# Lemo-Opuscar skill (plugin directory edition): put the bundled library in its working folder, then print its path.
#   sh setup.sh                    copy the library that ships with this plugin (when it is new or changed) → LIB=<path>
#   sh setup.sh deps [voice] [music]
#                                  the same, then install packages (see the library's tools/setup.sh)
# The library ships inside the plugin; nothing is cloned or fetched here. It is copied out because the packages
# (node_modules/, .venv/) and the models it downloads later should survive plugin updates.
# A file in the working folder that the user changed or added is never overwritten: when a new edition would replace
# one, the copy is skipped (the folder keeps its edition) and the files are listed. .edition-files records what each
# copy put there, so changed files can be told apart from files the last edition shipped. A folder or link where the
# new edition puts a file (or a file where it puts a folder) also stops the copy, and the edition marker and record
# change only after every file is in place.
# LEMO_OPUSCAR_HOME = the working folder (default ~/.lemo-opuscar).
set -e
SRC=$(cd "$(dirname "$0")/../library" && pwd -P)
LIB=${LEMO_OPUSCAR_HOME:-$HOME/.lemo-opuscar}
case "$LIB" in /*) ;; *) LIB=$(pwd)/$LIB ;; esac

# "<crc> <size> <path>" for every library file (paths relative, as ./x/y), in the folder given
sums() { (cd "$1" && find . -type f ! -path ./.edition ! -path ./.edition-files -exec cksum {} +) | sort -k3; }

stamp=$(cat "$SRC/.edition" 2>/dev/null || echo unknown)
if [ "$(cat "$LIB/.edition" 2>/dev/null)" != "$stamp" ]; then
  if [ -e "$LIB" ] && [ -n "$(ls -A "$LIB" 2>/dev/null)" ] && [ ! -f "$LIB/.edition" ]; then
    echo "✗ $LIB exists and is not a Lemo-Opuscar library folder. Set LEMO_OPUSCAR_HOME to another folder."; exit 1
  fi
  mkdir -p "$LIB"
  tmp=$(mktemp -d)
  sums "$SRC" > "$tmp/new"
  # the files this copy would replace, with their checksum in the working folder now
  : > "$tmp/cur"
  sed 's/^[^ ]* [^ ]* //' "$tmp/new" | while IFS= read -r f; do
    if [ -f "$LIB/$f" ]; then (cd "$LIB" && cksum "$f") >> "$tmp/cur"; fi
  done
  [ -f "$LIB/.edition-files" ] && cp "$LIB/.edition-files" "$tmp/old" || : > "$tmp/old"
  # a file is safe to replace when it already matches the new edition, or still matches what the last copy put there
  awk 'function key(l) { sub(/^[^ ]+ [^ ]+ /, "", l); return l }
       FILENAME == ARGV[1] { nw[key($0)] = $1 " " $2; next }
       FILENAME == ARGV[2] { od[key($0)] = $1 " " $2; next }
       { p = key($0); c = $1 " " $2; if (c != nw[p] && !(p in od && od[p] == c)) print p }' \
    "$tmp/new" "$tmp/old" "$tmp/cur" > "$tmp/changed"
  # paths the copy can't write at all (no backup helps): a folder or a link where a file goes, a file where a folder goes
  sed 's/^[^ ]* [^ ]* //' "$tmp/new" | while IFS= read -r f; do
    if [ -L "$LIB/$f" ] || [ -d "$LIB/$f" ]; then echo "$f"; continue; fi
    d=$(dirname "$f")
    while [ "$d" != . ]; do
      if [ -L "$LIB/$d" ] || { [ -e "$LIB/$d" ] && [ ! -d "$LIB/$d" ]; }; then echo "$d"; break; fi
      d=$(dirname "$d")
    done
  done | sort -u > "$tmp/blocked"
  if [ -s "$tmp/blocked" ] || { [ -s "$tmp/changed" ] && [ -f "$LIB/.edition-files" ]; }; then
    echo "! the plugin has a new library ($stamp), but these paths in $LIB were changed or added here, and the new"
    echo "  edition would replace them. Nothing was copied; $LIB keeps $(cat "$LIB/.edition" 2>/dev/null) and your files:"
    sort -u "$tmp/blocked" "$tmp/changed" | sed 's/^\.\//  /' | head -20
    echo "  To take the new edition, move these out of $LIB, then start again."
  else
    if [ -s "$tmp/changed" ]; then
      # copied by an older setup.sh that kept no record: changed files can't be told from old ones, so keep them all
      bak="$LIB/.lemo-backup-$(date +%Y%m%d-%H%M%S)"
      while IFS= read -r f; do mkdir -p "$bak/$(dirname "$f")"; cp -p "$LIB/$f" "$bak/$f"; done < "$tmp/changed"
      echo "! $(wc -l < "$tmp/changed" | tr -d ' ') library files in $LIB differ from the new edition; copies of them are in $bak"
    fi
    # copy over the old files; packages and downloaded models (node_modules/, .venv/, core/tts/*.onnx…) stay.
    # The edition marker and the record change only once every file is in place: a copy that fails half-way keeps the
    # old marker, so the next start tries again (the files it did replace were ones the last edition shipped).
    old=$(cat "$LIB/.edition" 2>/dev/null || true)
    if ! cp -R "$SRC/." "$LIB/"; then
      if [ -n "$old" ]; then printf '%s\n' "$old" > "$LIB/.edition"; else rm -f "$LIB/.edition"; fi
      echo "✗ the new library ($stamp) could not be copied completely into $LIB; it keeps ${old:-no} edition. Nothing of yours was replaced."
      rm -rf "$tmp"; exit 1
    fi
    cp "$tmp/new" "$LIB/.edition-files"
    echo "✓ library $stamp ready in $LIB"
  fi
  rm -rf "$tmp"
fi
LIB=$(cd "$LIB" && pwd -P)
exec sh "$LIB/tools/setup.sh" "$@"
