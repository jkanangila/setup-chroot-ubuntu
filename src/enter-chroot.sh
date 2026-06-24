#!/bin/bash
# File: ~/chroot/enter-chroot.sh
# Logs all operations to ~/chroot/ubuntu.log

set -e

CHROOT_PATH="$HOME/chroot/ubuntu"
CHROOT_NAME="ubuntu-chroot"
LOG_FILE="$HOME/chroot/ubuntu.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo "[$timestamp] [$level] $message"
}

log "INFO" "========== CHROOT SESSION START =========="
log "INFO" "Chroot path: $CHROOT_PATH"
log "INFO" "Log file: $LOG_FILE"

# Cleanup function - unmount everything
cleanup() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "An error occurred (exit code: $exit_code). Starting cleanup..."
    else
        log "INFO" "Session ended normally. Cleaning up mounts..."
    fi
    
    # Unmount in reverse order
    for mount_point in proc sys dev/pts dev run termux-data; do
        full_path="$CHROOT_PATH/$mount_point"
        if mountpoint -q "$full_path" 2>/dev/null; then
            log "INFO" "Unmounting $mount_point at $full_path"
            if umount -l "$full_path" 2>/dev/null; then
                log "INFO" "Successfully lazy-unmounted $mount_point"
            elif umount -f "$full_path" 2>/dev/null; then
                log "INFO" "Successfully force-unmounted $mount_point"
            else
                log "WARN" "Failed to unmount $mount_point, may be in use"
            fi
        else
            log "DEBUG" "$mount_point is not mounted"
        fi
    done
    
    log "INFO" "========== CHROOT SESSION END (exit code: $exit_code) =========="
    exit $exit_code
}

# Set trap to call cleanup on EXIT, INT, TERM
trap cleanup EXIT INT TERM

# Verify chroot exists
if [ ! -d "$CHROOT_PATH" ]; then
    log "ERROR" "Chroot directory not found: $CHROOT_PATH"
    exit 1
fi

log "INFO" "Chroot directory verified"

# Create necessary directories if they don't exist
for dir in proc sys dev dev/pts run termux-data; do
    dir_path="$CHROOT_PATH/$dir"
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        log "INFO" "Created directory: $dir_path"
    else
        log "DEBUG" "Directory already exists: $dir_path"
    fi
done

# Mount virtual filesystems
log "INFO" "Mounting virtual filesystems..."

if mount -t proc proc "$CHROOT_PATH/proc" 2>/dev/null; then
    log "INFO" "Mounted /proc"
else
    log "WARN" "/proc mount failed or already mounted"
fi

if mount -t sysfs sys "$CHROOT_PATH/sys" 2>/dev/null; then
    log "INFO" "Mounted /sys"
else
    log "WARN" "/sys mount failed or already mounted"
fi

if mount --rbind /dev "$CHROOT_PATH/dev" 2>/dev/null; then
    log "INFO" "Mounted /dev (rbind)"
else
    log "WARN" "/dev mount failed or already mounted"
fi

if mount -t devpts devpts "$CHROOT_PATH/dev/pts" -o gid=5,mode=620 2>/dev/null; then
    log "INFO" "Mounted /dev/pts"
else
    log "WARN" "/dev/pts mount failed or already mounted"
fi

if mount --rbind /run "$CHROOT_PATH/run" 2>/dev/null; then
    log "INFO" "Mounted /run (rbind)"
else
    log "WARN" "/run mount failed or already mounted"
fi

# Mount Termux data for tool access
if mount --rbind /data "$CHROOT_PATH/termux-data" 2>/dev/null; then
    log "INFO" "Mounted /data to /termux-data (rbind)"
else
    log "WARN" "/data mount failed or already mounted"
fi

# Setup resolv.conf for DNS
log "INFO" "Configuring DNS resolution..."
cat > "$CHROOT_PATH/etc/resolv.conf" << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF
log "INFO" "DNS configured: 8.8.8.8, 8.8.4.4, 1.1.1.1"

# Get actual UID/GID
ACTUAL_UID=$(id -u)
ACTUAL_GID=$(id -g)
log "INFO" "Running as UID: $ACTUAL_UID, GID: $ACTUAL_GID"

log "INFO" "All mounts successful. Entering chroot..."

# Enter chroot with full environment
chroot "$CHROOT_PATH" /bin/bash -c "
    export HOME=/root
    export TERM=xterm-256color
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export USER=root
    
    # Source bashrc if it exists
    [ -f /root/.bashrc ] && source /root/.bashrc
    
    # Start interactive shell
    exec /bin/bash -i
"


