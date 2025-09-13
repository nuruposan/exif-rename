#!/bin/bash

function abort() {
  echo -e "\naborted!" >&2
  exit 2
}

function checkenv() {
  type "exiftool" >/dev/null 2>&1; EQ=$?
  type "jq" >/dev/null 2>&1; JQ=$?

  if [ "$ET$JQ" -ne "00" ]; then
   echo "Please install exiftool and jq" >&2
   exit 3
  fi
}

function jq2tsv() {
  jq '.[0]' \
    | jq -r '["mv",."SourceFile",."File:Directory",."EXIF:CreateDate",."Composite:ImageSize",."EXIF:Model"]|@tsv'
}

function tsv2cmd() {
  sed -e "s/\t/ \"/" \
    -e "s/\t/\" \"/" \
    -e "s/\t/\//" \
    -e "s/\([0-9]\+\):\([0-9]\+\):\([0-9]\+\) /\1\2\3-/" \
    -e "s/\([0-9]\+\):\([0-9]\+\):\([0-9]\+\)\t/\1\2\3_/" \
    -e "s/\t/_/" \
    -e "s/$/.jpg\"/"
}

trap 'abort' INT

checkenv

SRC_DIR="$1"
if [ $# -ne 1 ] || [ ! -d "$SRC_DIR" ]; then
  {
    echo "usage:"
    echo "  $0 <TARGET_DIR> | tee <OUTPUT_SCRIPT>"
    echo "  bash <OUTPUT_SCRIPT>"
  } >&2

  exit 1
fi

FILE_NUM=`find $SRC_DIR | grep -i "jpg$" | wc -l`
if [ "$FILE_NUM" -eq "0" ]; then
  echo "No picture file found. Nothing to do!" >&2
  exit 0
fi


echo "#!/bin/bash"
echo "# target dir: $SRC_DIR"

LOOP_CNT=1
find $SRC_DIR | grep -i "jpg$" | while read JPEG_FILE; do
  if exiftool -exif -if '$exif' "$JPEG_FILE" >/dev/null; then
    echo -n "`exiftool -s -G -j "$JPEG_FILE" | jq2tsv | tsv2cmd`"
  else
    echo -n "# no EXIF: $JPEG_FILE"
  fi

  echo -n " "
  echo -ne "($LOOP_CNT/$FILE_NUM)\r" >&2
  echo ""

  ((LOOP_CNT = $LOOP_CNT + 1))
done
echo ""

exit 0
