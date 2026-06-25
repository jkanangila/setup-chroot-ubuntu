#!/bin/bash
# File: ~/chroot/setup-android-perms.sh
# Sets up Android permissions and storage access with logging

CHROOT_PATH="/data/data/com.termux/files/home/chroot/ubuntu"
LOG_FILE="/data/data/com.termux/files/home/chroot/ubuntu.log"

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

log "INFO" "========== ANDROID PERMISSIONS SETUP START =========="
log "INFO" "Chroot path: $CHROOT_PATH"

# Verify chroot exists
if [ ! -d "$CHROOT_PATH" ]; then
    log "ERROR" "Chroot directory not found: $CHROOT_PATH"
    exit 1
fi

# Create Android access directories
log "INFO" "Creating Android access points..."

mkdir -p "$CHROOT_PATH/android"
log "INFO" "Created /android directory"

# Create symlinks to Android storage
if ln -sf /storage/emulated/0 "$CHROOT_PATH/android/storage" 2>/dev/null; then
    log "INFO" "Created symlink: /android/storage -> /storage/emulated/0"
else
    log "WARN" "Failed to create /android/storage symlink or already exists"
fi

if ln -sf /sdcard "$CHROOT_PATH/android/sdcard" 2>/dev/null; then
    log "INFO" "Created symlink: /android/sdcard -> /sdcard"
else
    log "WARN" "Failed to create /android/sdcard symlink or already exists"
fi

if ln -sf /data/data "$CHROOT_PATH/android/appdata" 2>/dev/null; then
    log "INFO" "Created symlink: /android/appdata -> /data/data"
else
    log "WARN" "Failed to create /android/appdata symlink or already exists"
fi

# Create permission helper script
mkdir -p "$CHROOT_PATH/usr/local/bin"
cat > "$CHROOT_PATH/usr/local/bin/android-request-permissions" << 'EOF'
#!/bin/bash
# Request Android permissions via Termux
echo "[*] Requesting Android permissions via Termux API..."
if command -v termux-dialog &> /dev/null; then
    /data/data/com.termux/files/usr/bin/termux-dialog text -t "Permissions" -i "Requesting access to your Android device..."
else
    echo "[!] Termux API not available. You may need to install Termux:API"
fi
EOF

chmod +x "$CHROOT_PATH/usr/local/bin/android-request-permissions"
log "INFO" "Created android-request-permissions helper script"

# Add environment exports to bashrc
if [ -f "$CHROOT_PATH/root/.bashrc" ]; then
    if grep -q "Android Storage Access" "$CHROOT_PATH/root/.bashrc"; then
        log "WARN" "Android environment variables already exist in .bashrc"
    else
        echo "
# Android Storage Access
export ANDROID_STORAGE=/android/storage
export ANDROID_DATA=/android/appdata
export ANDROID_APPDATA=/android/appdata
alias android-storage='cd /android/storage'
alias android-sdcard='cd /android/sdcard'
" >> "$CHROOT_PATH/root/.bashrc"
        log "INFO" "Added Android environment variables to .bashrc"
    fi
else
    mkdir -p "$CHROOT_PATH/root"
    echo "
# Android Storage Access
export ANDROID_STORAGE=/android/storage
export ANDROID_DATA=/android/appdata
export ANDROID_APPDATA=/android/appdata
alias android-storage='cd /android/storage'
alias android-sdcard='cd /android/sdcard'
" > "$CHROOT_PATH/root/.bashrc"
    log "INFO" "Created .bashrc with Android environment variables"
fi

log "INFO" "========== ANDROID PERMISSIONS SETUP COMPLETE =========="
log "INFO" "Access points available:"
log "INFO" "  - Internal storage: /android/storage"
log "INFO" "  - SD card: /android/sdcard"
log "INFO" "  - App data: /android/appdata"
log "INFO" "  - Termux tools: /termux-data"
log "INFO" "Environment variables: ANDROID_STORAGE, ANDROID_DATA, ANDROID_APPDATA"
log "INFO" "Aliases: android-storage, android-sdcard"

