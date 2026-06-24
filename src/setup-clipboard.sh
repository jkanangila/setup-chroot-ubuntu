#!/bin/bash
# File: ~/chroot/setup-clipboard.sh
# Sets up clipboard sharing with logging

CHROOT_PATH="$HOME/chroot/ubuntu"
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

