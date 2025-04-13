#!/bin/sh

load_config() {
    eval "$(base64 -d "$LINK_CONFIG_FILE")"
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    else
        first_time_setup
    fi
}

load_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "Version file wasn't found!"
        sleep 2
        echo "Creating version file"
        sleep 2
        get_version
    fi
}

sanitize_filename() {
    echo "$1" | sed -e 's/[^[:alnum:]\._-]/_/g' -e 's/ /_/g'
}

get_json_value() {
    echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | sed "s/\"$2\":\"\([^\"]*\)\"/\1/" || \
    echo "$1" | grep -o "\"$2\":[^,}]*" | sed "s/\"$2\":\([^,}]*\)/\1/"
}

ensure_config_dir() {
    config_dir=$(dirname "$CONFIG_FILE")
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
    fi
}

cleanup() {
    rm -f /tmp/kindle_books.list \
          /tmp/kindle_folders.list \
          /tmp/search_results.json \
          /tmp/last_search_*
}

get_version() {
    api_response=$(curl -s -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/justrals/KindleFetch/commits") || {
        echo "Warning: Failed to fetch version from GitHub API" >&2
        echo "unknown"
        return
    }

    latest_sha=$(echo "$api_response" | grep -m1 '"sha":' | cut -d'"' -f4 | cut -c1-7)
    
    echo "$latest_sha" > "$VERSION_FILE"
    load_version
}

check_for_updates() {
    local current_sha=$(load_version)
    
    local latest_sha=$(curl -s -H "Accept: application/vnd.github.v3+json" \
        -H "Cache-Control: no-cache" \
        "https://api.github.com/repos/justrals/KindleFetch/commits?per_page=1" | \
        grep -oE '"sha": "[0-9a-f]+"' | head -1 | cut -d'"' -f4 | cut -c1-7)
    
    if [ -n "$latest_sha" ] && [ "$current_sha" != "$latest_sha" ]; then
        UPDATE_AVAILABLE=true
        return 0
    else
        return 1
    fi
}

save_config() {
    echo "KINDLE_DOCUMENTS=\"$KINDLE_DOCUMENTS\"" > "$CONFIG_FILE"
    echo "CREATE_SUBFOLDERS=\"$CREATE_SUBFOLDERS\"" >> "$CONFIG_FILE"
    echo "DEBUG_MODE=\"$DEBUG_MODE\"" >> "$CONFIG_FILE"
    echo "COMPACT_OUTPUT=\"$COMPACT_OUTPUT\"" >> "$CONFIG_FILE"
}