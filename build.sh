#!/bin/bash

# -e → exit on error
# -u → error on unset variables
# -o pipefail → fail if any part of a pipeline fails
set -euo pipefail

echo "---Starting build---"

### VARIABLES ###

BASE_DIR="$HOME/Projects/nate-spot-v3"

CONTENT_DIR="$BASE_DIR/content"
SITE_DIR="$BASE_DIR/site"
TEMP_DIR="$BASE_DIR/temp"

PAGES_DIR="$CONTENT_DIR/pages"
POSTS_DIR="$CONTENT_DIR/posts"

INDEX_MD="$PAGES_DIR/index.md"
INDEX_MD_TEMP="$TEMP_DIR/index.md"
POST_LIST_MD_TEMP="$TEMP_DIR/post-list.md"

### SETUP ###

if [ -d $SITE_DIR ]; then
    rm -rf $SITE_DIR
fi

if [ -d $TEMP_DIR ]; then
    rm -rf $TEMP_DIR
fi

mkdir $SITE_DIR
mkdir $TEMP_DIR

cp -r "$BASE_DIR/styles" "$SITE_DIR"
cp -r "$CONTENT_DIR/images" "$SITE_DIR"

cp $INDEX_MD $INDEX_MD_TEMP

### MAKE POSTS ###

find $POSTS_DIR -type f ! -name "*.sync-conflict*" -name "*.md" | while read FILE; do
    SLUG=$(basename "$FILE" .md)
    OUTPUT_PATH="$SITE_DIR/$SLUG"
    mkdir "$OUTPUT_PATH"
    echo "Making post: $SLUG"
    {
        read -r POST_TITLE;
        read -r POST_DATE;
    } < <(
        pandoc "$FILE" -o "$OUTPUT_PATH/index.html" \
            --template pandoc/base.html \
            --include-before-body pandoc/header.html \
            --lua-filter pandoc/meta.lua
    )

    ### ADD LINK TO POST LIST ###

    # POST_DATE_FORMATTED=$(date -d "$POST_DATE" "+%b %-d")
    printf "%s\n" "- [$POST_DATE]{.post-date} [$POST_TITLE](/$SLUG)" >> $POST_LIST_MD_TEMP
done

### ADD POST LIST TO INDEX ###

printf "\n%s\n" "::: post-list" >> $INDEX_MD_TEMP
cat $POST_LIST_MD_TEMP >> $INDEX_MD_TEMP
printf "%s\n" ":::" >> $INDEX_MD_TEMP

### MAKE PAGES ###

find $PAGES_DIR -type f ! -name "*.sync-conflict*" -name "*.md" | while read FILE; do
    SLUG=$(basename "$FILE" .md)
    OUTPUT_PATH="$SITE_DIR/$SLUG"
    INPUT_FILE="$FILE"

    echo "Making page: $SLUG"

    if [ $SLUG == "index" ]; then
        INPUT_FILE="$INDEX_MD_TEMP"
        OUTPUT_FILE="$OUTPUT_PATH.html"
    else
        mkdir "$OUTPUT_PATH"
        OUTPUT_FILE="$OUTPUT_PATH/index.html"
    fi

    pandoc "$INPUT_FILE" -o "$OUTPUT_FILE" \
        --template pandoc/base.html \
        --include-before-body pandoc/header.html
done

### CLEANUP ###

rm -rf $TEMP_DIR

echo "---Finished build---"
