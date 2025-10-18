#!/bin/bash

function onAbort() {
  echo -e "\naborted!" >&2
  exit 2
}

function checkEnv() {
  type "exiftool" >/dev/null 2>&1; EQ=$?
  type "jq" >/dev/null 2>&1; JQ=$?

  if [ "$ET$JQ" -ne "00" ]; then
   echo "Please install exiftool and jq" >&2
   exit 3
  fi
}

jq2tsv() {
  jq '.[0]' \
    | jq -r '[."EXIF:CreateDate",."Composite:ImageSize",."EXIF:Model"]|@tsv'
}

function tsv2dst() {
  sed -e "s/\([0-9]\+\):\([0-9]\+\):\([0-9]\+\) /\1\2\3-/" \
    -e "s/\([0-9]\+\):\([0-9]\+\):\([0-9]\+\)\t/\1\2\3_/" \
    -e "s/\t/_/" \
    -e "s/\t/_/" \
    -e "s/ /-/"
}

# verify that the required software is installed
checkEnv

# set Ctrl-C to call onAbort()
trap 'onAbort' INT

SRC_DIR="$1"
DST_DIR=`echo $2 | sed -e 's/\/$//'`

if [ $# -ne 2 ] || [ ! -d "${SRC_DIR}" ] || [ ! -d "${DST_DIR}" ]; then
  {
    echo "usage:"
    echo "  $0 SRC_DIR DEST_DIR | tee SCRIPT"
    echo "  bash SCRIPT"
  } >&2

  exit 1
fi

FILE_NUM=`find $SRC_DIR | grep -i -e "\.jpg$" -e "\.jpeg$" | wc -l`
if [ "$FILE_NUM" -eq "0" ]; then
  echo "No picture file found. Nothing to do!" >&2
  exit 0
fi

echo "#!/bin/bash"
echo ""
echo "# source dir: ${SRC_DIR} (${FILE_NUM} files)"
echo "# destination dir: ${DST_DIR}"
echo "# generated at: "`date "+%Y%m%d-%H%M%S"`
echo ""

LOOP_CNT=1
find $SRC_DIR | grep -i -e "\.jpg$" -e "\.jpeg$" | while read SRC_FILE; do
  echo -ne "\r($LOOP_CNT/$FILE_NUM) " >&2

  CHK_STR=`md5sum "${SRC_FILE}" | cut -c 1-6`

  if exiftool -exif -if '$exif' "$SRC_FILE" >/dev/null; then
    EXIF_JQ=`exiftool -s -G -j "${SRC_FILE}"`
    EXIF_TSV=`echo "${EXIF_JQ}" | jq2tsv`
    DST_FILE=`echo "${EXIF_TSV}" | tsv2dst`"_${CHK_STR}.jpg"

    echo "mv \"${SRC_FILE}\" \"${DST_DIR}/${DST_FILE}\""
  else
    echo "# no EXIF: ${SRC_FILE}"
  fi

  ((LOOP_CNT = ${LOOP_CNT} + 1))
done
echo ""

exit 0
