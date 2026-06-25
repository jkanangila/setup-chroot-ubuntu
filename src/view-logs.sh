#!/bin/bash
# File: ~/chroot/view-logs.sh
# View and manage logs

LOG_FILE="/data/data/com.termux/files/home/chroot/ubuntu.log"

if [ ! -f "$LOG_FILE" ]; then
    echo "No log file found at $LOG_FILE"
    exit 1
fi

case "${1:-tail}" in
    tail)
        echo "=== Latest 50 entries ==="
        tail -50 "$LOG_FILE"
        ;;
    head)
        echo "=== First 50 entries ==="
        head -50 "$LOG_FILE"
        ;;
    all)
        echo "=== Full log ==="
        cat "$LOG_FILE"
        ;;
    errors)
        echo "=== Error entries ==="
        grep "\[ERROR\]" "$LOG_FILE"
        ;;
    warnings)
        echo "=== Warning entries ==="
        grep "\[WARN\]" "$LOG_FILE"
        ;;
    sessions)
        echo "=== Session starts/ends ==="
        grep "SESSION" "$LOG_FILE"
        ;;
    follow)
        echo "=== Following log (Ctrl+C to stop) ==="
        tail -f "$LOG_FILE"
        ;;
    clear)
        echo "Clearing log file..."
        > "$LOG_FILE"
        echo "Log cleared."
        ;;
    *)
        echo "Usage: $0 {tail|head|all|errors|warnings|sessions|follow|clear}"
        ;;
esac

