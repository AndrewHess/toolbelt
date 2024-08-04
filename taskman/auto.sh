#!/bin/bash

script_dir="$(dirname "$0")"
output_file="$script_dir/main.md"
lock_file="$output_file.lock"
lock_wait_time=10

function append_tasks() {
    if acquire_lock; then
        for item in "$@"; do
            echo "- $item" >> "$output_file"
        done

        release_lock
    else
        echo "Could not acquire lock on $lock_file" >&2
        exit 1
    fi
}

function delete_done_tasks() {
    if acquire_lock; then
        sed -i.bak '/^- .*@done/,/^- /{ /^- .*@done.*/d; /^- /!d; }' "$output_file"
        release_lock
    else
        echo "Could not acquire lock on $lock_file" >&2
        exit 1
    fi    
}

acquire_lock() {
    local start=$(date +%s)
    while ! mkdir "$lock_file" 2>/dev/null; do
        if (( $(date +%s) - start >= lock_wait_time )); then
            return 1  # Timeout
        fi
        sleep 1
    done
    return 0
}

release_lock() {
    rmdir "$lock_file" 2>/dev/null
}

"$@" # See https://stackoverflow.com/a/16159057
