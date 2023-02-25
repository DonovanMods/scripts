#!env bash
# Converts all Devin Night ZIPs in a directory from PNGs to WebP

_convert_to_webp() {
  local FILE="$1"
  local BASE="${FILE%.*}"
  local OUT="$2"

  if [[ -z "$OUT" ]]; then
    OUT="${BASE%_hi}.webp"
  fi

  # _log "Converting $FILE to $OUT"
  cwebp -quiet -q 100 -lossless "$FILE" -o "$OUT" && rm "$FILE"
}

_unzip_images() {
  local ZIP="$1"
  local DIR="$2"

  if [[ -z "$ZIP" || -z "$DIR" ]]; then
    _log "unzip_images requires a ZIP and DIR"
    return 1
  fi

  _log "Extracting hi-res PNGs from $ZIP to $DIR"
  unzip -qqojC "$ZIP" "*_hi.png" "*hi*/*.png" "*400*/*.png" -x "__MACOSX/**" -d "$DIR" 2>/dev/null

  if ls "$DIR"/*.png >/dev/null 2>&1; then
    return 0
  else
    # Last ditch effort if the above fails
    _log "Failed to find any hi-res images, unzipping all PNGs"
    unzip -qqojC "$ZIP" "*.png" -x "__MACOSX/**" -d "$DIR" 2>/dev/null

    ls "$DIR"/*.png >/dev/null 2>&1

    return $?
  fi
}

_log() {
  local MSG="$1"

  echo "$MSG" | tee -a $LOGFILE
}

# Create and add timestamp to the $LOGFILE file
LOGFILE="${0%.sh}.log"

echo "Logging output to $LOGFILE"
_log "Starting conversion at $(date)"

# Check for cwebp
which cwebp >/dev/null || {
  _log "This script requires 'cwebp' to be installed and in your \$PATH"
  exit 1
}

ls *.zip >/dev/null 2>&1 || {
  _log "No ZIP files found"
  exit 1
}

# Create the webp directory if it doesn't exist
[[ -d "webp" ]] || mkdir webp

for ZIP in *.zip; do
  DIR="${ZIP%.zip}"

  if [[ -d "$DIR" ]]; then
    _log "skipping $ZIP; if this is unexpected, please remove $DIR and run this again"
    continue
  fi

  if _unzip_images "$ZIP" "$DIR"; then
    _log "Converting files in $DIR"
    cd $DIR
    for FILE in *.png; do
      _convert_to_webp "$FILE" &
    done
    wait # for all backgrounded _convert_to_webp processes to finish
    cd ..
    _log "Converted $(ls "$DIR"/*.webp | wc -l) images"
    _log "Zipping $DIR"
    zip -q -r "webp/$DIR.webp.zip" "$DIR" && unzip -tq "webp/$DIR.webp.zip"
    if [[ $? -eq 0 ]]; then
      rm -rf "$DIR" "$ZIP"
    else
      _log "Failed to Zip $DIR"
    fi
  else
    _log "Failed to Unzip $ZIP"
    [[ -d "$DIR" ]] && rm -rf "$DIR"
    continue
  fi
done

_log "Converted $(ls webp/*.zip | wc -l) ZIP files to webp"
_log "Completed Processing at $(date)"
