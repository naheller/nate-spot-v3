#!/bin/bash

# -e → exit on error
# -u → error on unset variables
# -o pipefail → fail if any part of a pipeline fails
set -euo pipefail

echo "-- Building site --"

### FUNCTIONS ###

function slugify() {
    echo "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E "s/['’]//g; s/[^a-z0-9]+/-/g; s/^-+|-+$//g"
}

### VARIABLES ###

BASE_DIR="$HOME/Projects/nate-spot-v3"

# CONTENT_DIR="$BASE_DIR/content"
CONTENT_DIR="$HOME/Documents/Notes/Natespot"
SITE_DIR="$BASE_DIR/site"

PAGES_DIR="$CONTENT_DIR/pages"
POSTS_DIR="$CONTENT_DIR/posts"

TEMP_DIR="$BASE_DIR/temp"
PAGES_DIR_TEMP="$TEMP_DIR/pages"
POSTS_DIR_TEMP="$TEMP_DIR/posts"

INDEX_MD="$PAGES_DIR/index.md"
INDEX_MD_TEMP="$PAGES_DIR_TEMP/index.md"
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

mkdir $PAGES_DIR_TEMP
mkdir $POSTS_DIR_TEMP

cp -r "$BASE_DIR/styles" "$SITE_DIR"
cp -r "$CONTENT_DIR/images" "$SITE_DIR"

cp $INDEX_MD $INDEX_MD_TEMP

### MAKE POSTS ###

find $POSTS_DIR -type f ! -name "*.sync-conflict*" -name "*.md" | while read FILE; do
    POST_TITLE=$(basename "$FILE" .md)
    POST_SLUG_FALLBACK=$(slugify "$POST_TITLE") # Use slugified post title as fallback if no slug provided
    POST_TEMP="$POSTS_DIR_TEMP/$POST_SLUG_FALLBACK.html"

    echo "Making post: $POST_TITLE"

    {
        read -r POST_SLUG;
        read -r POST_DATE;
    } < <(
        pandoc "$FILE" -o "$POST_TEMP" \
            --metadata title="$POST_TITLE" \
            --template pandoc/base.html \
            --include-before-body pandoc/header.html \
            --lua-filter pandoc/meta.lua
    )

    ### COPY TEMP POST TO SITE DIR ###

    if [[ -z "$POST_SLUG" ]]; then
        POST_SLUG="$POST_SLUG_FALLBACK"
    fi

    mkdir "$SITE_DIR/$POST_SLUG"
    cat "$POST_TEMP" >> "$SITE_DIR/$POST_SLUG/index.html"

    ### ADD LINK TO POST LIST ###

    # POST_DATE_FORMATTED=$(date -d "$POST_DATE" "+%b %-d")
    printf "%s\n" "- [$POST_TITLE](/$POST_SLUG) [$POST_DATE]{.post-date} " >> $POST_LIST_MD_TEMP
done

### ADD POST LIST TO INDEX ###

printf "\n\n%s\n" "::: post-list" >> $INDEX_MD_TEMP
cat $POST_LIST_MD_TEMP >> $INDEX_MD_TEMP
printf "%s\n" ":::" >> $INDEX_MD_TEMP

### MAKE PAGES ###

find $PAGES_DIR -type f ! -name "*.sync-conflict*" -name "*.md" | while read FILE; do
    PAGE_TITLE=$(basename "$FILE" .md)
    PAGE_SLUG_FALLBACK=$(slugify "$PAGE_TITLE") # Use slugified page title as fallback if no slug provided
    PAGE_TEMP="$PAGES_DIR_TEMP/$PAGE_SLUG_FALLBACK.html"

    echo "Making page: $PAGE_TITLE"

    ### HANDLE INDEX PAGE SEPARATELY ###

    if [[ $PAGE_TITLE == "index" ]]; then
        INPUT_FILE="$INDEX_MD_TEMP"
        OUTPUT_FILE="$SITE_DIR/$PAGE_TITLE.html"

        pandoc "$INPUT_FILE" -o "$OUTPUT_FILE" \
            --template pandoc/base.html \
            --include-before-body pandoc/header.html \
            --lua-filter pandoc/meta.lua
    else
        {
            read -r PAGE_SLUG;
        } < <(
            pandoc "$FILE" -o "$PAGE_TEMP" \
                --metadata title="$PAGE_TITLE" \
                --template pandoc/base.html \
                --include-before-body pandoc/header.html \
                --lua-filter pandoc/meta.lua
        )

        ### COPY TEMP PAGE TO SITE DIR ###

        if [[ -z "$PAGE_SLUG" ]]; then
            PAGE_SLUG=$PAGE_SLUG_FALLBACK
        fi

        mkdir "$SITE_DIR/$PAGE_SLUG"
        cat "$PAGE_TEMP" >> "$SITE_DIR/$PAGE_SLUG/index.html"
    fi
done

### CLEANUP ###

rm -rf $TEMP_DIR

echo "-- Finished building --"
