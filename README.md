# Ubuntu 24 Chroot on Termux - Complete Setup Guide

## Prerequisites
* Termux installed on your rooted Tecno Spark Slim
* Root access (which you have)
* ~2-3GB free storage space
* `proot-distro` package (easier than manual chroot) OR manual chroot setup

## Option 1: Quick Setup with proot-distro (Recommended)
This is the simplest approach. Install in Termux:

```bash
pkg update && pkg upgrade
pkg install proot-distro
proot-distro install ubuntu
proot-distro login ubuntu

```
However, since you specifically want a rooted chroot with full permissions, use **Option 2** below.

## Option 2: Manual Ubuntu 24 Chroot Setup
### Step 1: Download and Extract Ubuntu Rootfs
In Termux:
```bash
# Create workspace
mkdir -p /data/data/com.termux/files/home/chroot
cd /data/data/com.termux/files/home/chroot

# Download Ubuntu 24.04 LTS ARM64 rootfs
# You can get this from several sources:
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04.4-server-cloudimg-arm64-root.tar.xz

# Or use a minimal base:
wget https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz

# Extract
tar -xzf ubuntu-base-24.04-base-arm64.tar.gz -C ./ubuntu/
# Or for xz:
# tar -xJf ubuntu-24.04-server-cloudimg-arm64-root.tar.xz -C ./ubuntu/

mkdir -p ubuntu
```
### Step 2: Create the Mount & Entry Script
Here's your main entry script with error handling:
```bash
#!/bin/bash
# File: ~/chroot/enter-chroot.sh
# Logs all operations to ~/chroot/ubuntu.log

set -e

CHROOT_PATH="/data/data/com.termux/files/home/chroot/ubuntu"
CHROOT_NAME="ubuntu-chroot"
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

```
### Step 3: Clipboard Sharing Script
Create a clipboard bridge between chroot and Termux:
```bash
#!/bin/bash
# File: ~/chroot/setup-clipboard.sh
# Sets up clipboard sharing with logging

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

log "INFO" "========== CLIPBOARD SETUP START =========="
log "INFO" "Chroot path: $CHROOT_PATH"

# Verify chroot exists
if [ ! -d "$CHROOT_PATH" ]; then
    log "ERROR" "Chroot directory not found: $CHROOT_PATH"
    exit 1
fi

# Create necessary directories
mkdir -p "$CHROOT_PATH/usr/local/bin"
log "INFO" "Created /usr/local/bin directory in chroot"

# Create clipboard copy script
cat > "$CHROOT_PATH/usr/local/bin/termux-clipboard-set" << 'EOF'
#!/bin/bash
# Write to Android clipboard via Termux
if [ -n "$1" ]; then
    echo "$1" | /data/data/com.termux/files/usr/bin/termux-clipboard-set
else
    cat | /data/data/com.termux/files/usr/bin/termux-clipboard-set
fi
EOF

log "INFO" "Created termux-clipboard-set script"

# Create clipboard paste script
cat > "$CHROOT_PATH/usr/local/bin/termux-clipboard-get" << 'EOF'
#!/bin/bash
# Read from Android clipboard via Termux
/data/data/com.termux/files/usr/bin/termux-clipboard-get
EOF

log "INFO" "Created termux-clipboard-get script"

# Make scripts executable
chmod +x "$CHROOT_PATH/usr/local/bin/termux-clipboard-set"
chmod +x "$CHROOT_PATH/usr/local/bin/termux-clipboard-get"
log "INFO" "Made clipboard scripts executable"

# Create alias setup in chroot bashrc
if [ -f "$CHROOT_PATH/root/.bashrc" ]; then
    if grep -q "Clipboard sharing with Termux" "$CHROOT_PATH/root/.bashrc"; then
        log "WARN" "Clipboard aliases already exist in .bashrc"
    else
        echo "
# Clipboard sharing with Termux
alias copy='termux-clipboard-set'
alias paste='termux-clipboard-get'
alias xclip='termux-clipboard-set'
" >> "$CHROOT_PATH/root/.bashrc"
        log "INFO" "Added clipboard aliases to .bashrc (copy, paste, xclip)"
    fi
else
    mkdir -p "$CHROOT_PATH/root"
    echo "
# Clipboard sharing with Termux
alias copy='termux-clipboard-set'
alias paste='termux-clipboard-get'
alias xclip='termux-clipboard-set'
" > "$CHROOT_PATH/root/.bashrc"
    log "INFO" "Created .bashrc with clipboard aliases"
fi

log "INFO" "========== CLIPBOARD SETUP COMPLETE =========="
log "INFO" "Aliases available: copy, paste, xclip"
log "INFO" "Example: echo 'text' | copy"
```

### Step 4: Android Permission Setup
For full Android permissions in chroot, run this initialization script:
```bash
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
```

### Step 5: Log Viewer Script (Optional)
```bash
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
```
#### View Logs Commands
```bash
# Tail latest entries
./view-logs.sh tail

# Follow log in real-time
./view-logs.sh follow

# View all errors
./view-logs.sh errors

# View all warnings
./view-logs.sh warnings

# See all sessions
./view-logs.sh sessions

# Clear old logs
./view-logs.sh clear
```

### Complete Installation Workflow
```bash
# 1. Create directories
mkdir -p /data/data/com.termux/files/home/chroot/ubuntu
cd /data/data/com.termux/files/home/chroot

# 2. Download Ubuntu base (arm64)
wget https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz

# 3. Extract
tar -xzf ubuntu-base-24.04.4-base-arm64.tar.gz -C ./ubuntu/

# 4. Copy all scripts into ~/chroot/
# (Copy each script file created above)

# 5. Make scripts executable
chmod +x ~/chroot/{enter-chroot.sh,setup-clipboard.sh,setup-android-perms.sh,view-logs.sh}

# 6. Run setup scripts
./setup-clipboard.sh      # Logs to ubuntu.log
./setup-android-perms.sh  # Logs to ubuntu.log

# 7. View logs
./view-logs.sh tail       # See latest entries

# 8. Enter chroot (all operations logged)
./enter-chroot.sh
```
### Quick Reference Commands
```bash
# Enter chroot
~/chroot/enter-chroot.sh

# Copy to Android clipboard from within chroot
echo "Hello from Ubuntu" | copy

# Paste from Android clipboard
paste

# Access Android storage
cd /android/storage

# Exit chroot (cleanup happens automatically)
exit

```
## Important Notes
1. **Root Access**: Your device is already rooted, so you have full permissions. The scripts run as root in chroot by default.

2. **Trap Mechanism**: The cleanup function is triggered by:
  * `EXIT`: Normal exit
  * `INT`: Ctrl+C interrupt
  * `TERM`: Termination signal
  * Any errors due to `set -e`

3. **TTY Support**: The chroot uses `/bin/bash -i` which ensures full interactive TTY with history and editing.

4. **Storage**: If you run out of space, you can use external SD card by mounting it:

```bash
mount --rbind /storage/emulated/0 $CHROOT_PATH/mnt/storage
```
5. **DNS**: The script sets Google DNS; modify `/etc/resolv.conf` if needed.

6. **Clipboard Limitations**: Clipboard sharing requires `/data/data/com.termux/files/usr/bin/termux-clipboard-set` and `-get` to be present. If missing, install the Termux API addon.
