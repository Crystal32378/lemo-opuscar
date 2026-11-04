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
# new edition puts a file (or a file where it puts a folder) also stops the copy. Files are copied one by one under a
# temporary name and renamed into place, and the edition marker is written last, so an interrupted copy is finished
# on the next start instead of being taken for a complete one.
# LEMO_OPUSCAR_HOME = the working folder (default ~/.lemo-opuscar).
set -e
SRC=$(cd "$(dirname "$0")/../library" && pwd -P)
LIB=${LEMO_OPUSCAR_HOME:-$HOME/.lemo-opuscar}
case "$LIB" in /*) ;; *) LIB=$(pwd)/$LIB ;; esac

# "<crc> <size> <path>" for every library file (paths relative, as ./x/y), in the folder given
sums() { (cd "$1" && find . -type f ! -path ./.edition ! -path ./.edition-files -exec cksum {} +) | sort -k3; }

stamp=$(cat "$SRC/.edition" 2>/dev/null || echo unknown)
if [ "$(cat "$LIB/.edition" 2>/dev/null)" != "$stamp" ]; then
  # .lemo-library marks a folder this script made, from before the first file lands, so a first copy that was cut off
  # is recognised (and finished) on the next start instead of being taken for someone else's folder
  if [ -e "$LIB" ] && [ -n "$(ls -A "$LIB" 2>/dev/null)" ] && [ ! -f "$LIB/.edition" ] && [ ! -f "$LIB/.lemo-library" ]; then
    echo "✗ $LIB exists and is not a Lemo-Opuscar library folder. Set LEMO_OPUSCAR_HOME to another folder."; exit 1
  fi
  mkdir -p "$LIB"; : > "$LIB/.lemo-library"
  # One copy at a time: two sessions starting together would otherwise write the same files. A lock left by a copy
  # that was killed (its process is gone) is taken over.
  lock="$LIB/.lemo-lock"; waited=0
  until mkdir "$lock" 2>/dev/null; do
    holder=$(cat "$lock/pid" 2>/dev/null || true)
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$lock"; continue; fi
    [ -z "$holder" ] && [ "$waited" -ge 5 ] && { rm -rf "$lock"; continue; }   # a lock that never got its pid
    [ "$waited" = 2 ] && echo "… another start is copying the library into $LIB; waiting for it"
    sleep 1; waited=$((waited + 1))
  done
  echo $$ > "$lock/pid"; trap 'rm -rf "$lock"' EXIT; trap 'rm -rf "$lock"; exit 130' INT TERM
  # the copy that held the lock may have just finished this very edition
  if [ "$(cat "$LIB/.edition" 2>/dev/null)" != "$stamp" ]; then
    tmp=$(mktemp -d)
    sums "$SRC" > "$tmp/new"
    sed 's/^[^ ]* [^ ]* //' "$tmp/new" > "$tmp/list"
    # temporary copies left by a copy that was cut off (see below) are ours: remove them first
    while IFS= read -r f; do rm -f "$LIB/$f.lemo-new"; done < "$tmp/list"
    rm -f "$LIB/.edition.lemo-new" "$LIB/.edition-files.lemo-new"
    # the files this copy would replace, with their checksum in the working folder now
    : > "$tmp/cur"
    while IFS= read -r f; do
      if [ -f "$LIB/$f" ]; then (cd "$LIB" && cksum "$f") >> "$tmp/cur"; fi
    done < "$tmp/list"
    [ -f "$LIB/.edition-files" ] && cp "$LIB/.edition-files" "$tmp/old" || : > "$tmp/old"
    # a file is safe to replace when it already matches the new edition, or still matches what the last copy put there
    awk 'function key(l) { sub(/^[^ ]+ [^ ]+ /, "", l); return l }
         FILENAME == ARGV[1] { nw[key($0)] = $1 " " $2; next }
         FILENAME == ARGV[2] { od[key($0)] = $1 " " $2; next }
         { p = key($0); c = $1 " " $2; if (c != nw[p] && !(p in od && od[p] == c)) print p }' \
      "$tmp/new" "$tmp/old" "$tmp/cur" > "$tmp/changed"
    # paths the copy can't write at all (no backup helps): a folder or a link where a file goes, a file where a folder goes
    while IFS= read -r f; do
      if [ -L "$LIB/$f" ] || [ -d "$LIB/$f" ]; then echo "$f"; continue; fi
      d=$(dirname "$f")
      while [ "$d" != . ]; do
        if [ -L "$LIB/$d" ] || { [ -e "$LIB/$d" ] && [ ! -d "$LIB/$d" ]; }; then echo "$d"; break; fi
        d=$(dirname "$d")
      done
    done < "$tmp/list" | sort -u > "$tmp/blocked"
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
      # Copy file by file; packages and downloaded models (node_modules/, .venv/, core/tts/*.onnx…) stay. Each file is
      # written under a temporary name and renamed into place, so a copy cut off at any moment (an error, Ctrl-C, a kill,
      # a power cut) leaves every file whole, old or new. The record and then the edition marker are written last, the
      # same way: until the marker changes, the next start sees the old edition and copies again (the files already
      # replaced match the new edition, so they count as safe).
      old=$(cat "$LIB/.edition" 2>/dev/null || true)
      failed=
      while IFS= read -r f; do
        mkdir -p "$LIB/$(dirname "$f")" && cp -p "$SRC/$f" "$LIB/$f.lemo-new" && mv -f "$LIB/$f.lemo-new" "$LIB/$f" \
          || { rm -f "$LIB/$f.lemo-new"; failed=$f; break; }
      done < "$tmp/list"
      if [ -n "$failed" ]; then
        echo "✗ the new library ($stamp) could not be copied completely into $LIB (stopped at ${failed#./}); it keeps ${old:-no} edition and will try again next time. Nothing of yours was replaced."
        rm -rf "$tmp"; exit 1
      fi
      cp "$tmp/new" "$LIB/.edition-files.lemo-new" && mv -f "$LIB/.edition-files.lemo-new" "$LIB/.edition-files"
      printf '%s\n' "$stamp" > "$LIB/.edition.lemo-new" && mv -f "$LIB/.edition.lemo-new" "$LIB/.edition"
      echo "✓ library $stamp ready in $LIB"
    fi
    rm -rf "$tmp"
  fi
  rm -rf "$lock"; trap - EXIT INT TERM
fi
LIB=$(cd "$LIB" && pwd -P)
exec sh "$LIB/tools/setup.sh" "$@"
