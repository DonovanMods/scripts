#!env bash
# Converts all Devin Night ZIPs in a directory from PNGs to WebP

_convert_to_webp() {
  local FILE="$1"
  local BASE="${FILE%.*}"
  local OUT="$2"

  if [[ -z "$OUT" ]]; then
    OUT="${BASE%_hi}.webp"
  fi

  # echo "Converting $FILE to $OUT" | tee -a $LOGFILE
  cwebp -quiet -q 100 -lossless "$FILE" -o "$OUT" && rm "$FILE"
}

_unzip_images() {
  local ZIP="$1"
  local DIR="$2"

  if [[ -z "$ZIP" || -z "$DIR" ]]; then
    echo "unzip_images requires a ZIP and DIR" | tee -a $LOGFILE
    return 1
  fi

  echo "Extracting hi-res PNGs from $ZIP to $DIR" | tee -a $LOGFILE
  unzip -qqojC "$ZIP" "*_hi.png" "*hi*/*.png" "*400*/*.png" -x "__MACOSX/**" -d "$DIR" 2>/dev/null

  if ls "$DIR"/*.png >/dev/null 2>&1; then
    return 0
  else
    # Last ditch effort if the above fails
    echo "Failed to find any hi-res images, unzipping all PNGs" | tee -a $LOGFILE
    unzip -qqojC "$ZIP" "*.png" -x "__MACOSX/**" -d "$DIR" 2>/dev/null

    ls "$DIR"/*.png >/dev/null 2>&1

    return $?
  fi
}

# Create and add timestamp to the $LOGFILE file
LOGFILE="${0%.sh}.log"

echo "Logging output to $LOGFILE"
echo "Starting conversion at $(date)" | tee -a $LOGFILE

# Check for cwebp
which cwebp >/dev/null || {
  echo "This script requires 'cwebp' to be installed and in your \$PATH" | tee -a $LOGFILE
  exit 1
}

ls *.zip >/dev/null 2>&1 || {
  echo "No ZIP files found" | tee -a $LOGFILE
  exit 1
}

# Create the webp directory if it doesn't exist
[[ -d "webp" ]] || mkdir webp

for ZIP in *.zip; do
  DIR="${ZIP%.zip}"

  if [[ -d "$DIR" ]]; then
    echo "skipping $ZIP; if this is unexpected, please remove $DIR and run this again" | tee -a $LOGFILE
    continue
  fi

  if _unzip_images "$ZIP" "$DIR"; then
    echo "Converting files in $DIR" | tee -a $LOGFILE
    cd $DIR
    for FILE in *.png; do
      _convert_to_webp "$FILE" &
    done
    wait # for all backgrounded _convert_to_webp processes to finish
    cd ..
    echo "Converted $(ls "$DIR"/*.webp | wc -l) images" | tee -a $LOGFILE
    echo "Zipping $DIR" | tee -a $LOGFILE
    zip -q -r "webp/$DIR.webp.zip" "$DIR" && unzip -tq "webp/$DIR.webp.zip" && rm -rf "$DIR" "$ZIP" || echo "Failed to Zip $DIR" | tee -a $LOGFILE
  else
    echo "Failed to Unzip $ZIP" | tee -a $LOGFILE
    [[ -d "$DIR" ]] && rm -rf "$DIR"
    continue
  fi
done

echo "Converted $(ls webp/*.zip | wc -l) ZIP files to webp" | tee -a $LOGFILE
echo "Completed Processing at $(date)" | tee -a $LOGFILE
