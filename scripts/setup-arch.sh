#!/usr/bin/env bash
# =============================================================================
# gdrive-music — Setup Wizard (Arch-based)
# Distros: Arch Linux · Manjaro · CachyOS · EndeavourOS · Garuda · ArcoLinux
# Streams Google Drive music to your terminal: rclone + MPD + rmpc + cava
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── State ─────────────────────────────────────────────────────────────────────
STEP=0
TOTAL_STEPS=9
HOME_DIR="$HOME"
RCLONE_BIN=""
FUSERMOUNT_BIN=""
RCLONE_SOURCE=""

# ── Helpers ───────────────────────────────────────────────────────────────────
header() {
  clear
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║          gdrive-music  —  Setup Wizard                  ║"
  echo "  ║    Stream Google Drive music from your terminal          ║"
  echo "  ║    Arch · Manjaro · CachyOS · EndeavourOS · Garuda      ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

progress() {
  local filled=$(( STEP * 30 / TOTAL_STEPS ))
  local empty=$(( 30 - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  echo -e "  ${DIM}Progress:${RESET}\n  ${CYAN}[${bar}]${RESET} ${BOLD}Step $STEP of $TOTAL_STEPS${RESET}\n"
}

step_header() {
  STEP=$((STEP + 1))
  header
  progress
  echo -e "  ${BOLD}${BLUE}━━━ Step $STEP: $1 ━━━${RESET}\n"
}

success() { echo -e "\n  ${GREEN}✓${RESET} $1"; }
info()    { echo -e "  ${CYAN}→${RESET} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $1"; }

divider() {
  echo -e "  ${DIM}──────────────────────────────────────────────────────────${RESET}"
}

fail() {
  echo ""
  echo -e "  ${RED}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${RED}║  ✗  Step failed: $1${RESET}"
  echo -e "  ${RED}╠══════════════════════════════════════════════════════════╣${RESET}"
  echo -e "  ${RED}║  $2${RESET}"
  echo -e "  ${RED}╠══════════════════════════════════════════════════════════╣${RESET}"
  echo -e "  ${YELLOW}║  Fix: $3${RESET}"
  echo -e "  ${RED}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${DIM}Fix the issue above and re-run: bash scripts/setup-arch.sh${RESET}"
  echo ""
  exit 1
}

ask() {
  echo -e "\n  ${BOLD}$1${RESET}"
  echo -ne "  ${CYAN}[y/n]${RESET} → "
  read -r REPLY
  echo ""
  [[ "$REPLY" =~ ^[Yy]$ ]]
}

ask_input() {
  echo -e "\n  ${BOLD}$1${RESET}" >&2
  echo -ne "  ${CYAN}→${RESET} " >&2
  read -r INPUT
  echo "$INPUT"
}

side_panel() {
  local title="$1"; shift
  echo ""
  echo -e "  ${MAGENTA}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${MAGENTA}║  📋  $title${RESET}"
  echo -e "  ${MAGENTA}╠══════════════════════════════════════════════════════════╣${RESET}"
  for line in "$@"; do
    echo -e "  ${MAGENTA}║${RESET}  $line"
  done
  echo -e "  ${MAGENTA}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

cmd_exists() { command -v "$1" &>/dev/null; }

detect_audio() {
  if pactl info 2>/dev/null | grep -qi "pipewire"; then
    echo "pipewire"
  elif pactl info 2>/dev/null | grep -qi "pulseaudio"; then
    echo "pulse"
  elif cmd_exists "pw-cli"; then
    echo "pipewire"
  else
    echo "pipewire"
  fi
}

# =============================================================================
# WELCOME
# =============================================================================
header
echo -e "  ${BOLD}Welcome!${RESET} This sets up a terminal music player"
echo -e "  that streams directly from your Google Drive."
echo ""
echo -e "  ${DIM}Installs:${RESET} rclone · MPD · rmpc · cava · tmux"
echo -e "  ${DIM}Time:${RESET}     ~10 minutes + Google login"
echo ""
divider
echo ""

if ! ask "Ready to start?"; then
  echo -e "  ${YELLOW}Cancelled.${RESET}"
  exit 0
fi

# =============================================================================
# STEP 1 — DETECT SYSTEM
# =============================================================================
step_header "Detecting your system"

DETECTED_ID=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown")
DETECTED_NAME=$(grep "^NAME=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown")

info "Username:  $(whoami)"
info "Home:      $HOME_DIR"
info "Distro:    $DETECTED_NAME ($DETECTED_ID)"
info "Pkg mgr:   pacman"

AUDIO_TYPE=$(detect_audio)
info "Audio:     $AUDIO_TYPE"

ARCH_MACHINE=$(uname -m)
info "Arch:      $ARCH_MACHINE"

# Validate this is actually an Arch-based system
if ! cmd_exists pacman; then
  fail "System check" \
    "pacman not found — this script is for Arch-based distros only" \
    "Use the correct setup script for your distro"
fi

success "System detected: $DETECTED_NAME"

# =============================================================================
# STEP 2 — INSTALL PACKAGES
# =============================================================================
step_header "Installing required packages"

info "Syncing package database..."
sudo pacman -Sy --noconfirm 2>/dev/null || warn "pacman -Sy had warnings, continuing..."

echo ""
info "Installing: rclone fuse3 mpd mpc cava tmux"
echo ""

# Install all packages — all available in official Arch repos
if ! sudo pacman -S --noconfirm --needed rclone fuse3 mpd mpc cava tmux 2>&1; then
  fail "Package install" "pacman failed to install packages" \
    "sudo pacman -S rclone fuse3 mpd mpc cava tmux"
fi

# Resolve binary paths dynamically — avoids hardcoded /usr/bin assumptions
RCLONE_BIN=$(command -v rclone 2>/dev/null || true)
FUSERMOUNT_BIN=$(command -v fusermount3 2>/dev/null || command -v fusermount 2>/dev/null || true)

if [[ -z "$RCLONE_BIN" ]]; then
  fail "rclone path" "rclone installed but binary not found in PATH" \
    "which rclone — then re-run this script"
fi

if [[ -z "$FUSERMOUNT_BIN" ]]; then
  fail "fusermount" "fusermount3/fusermount not found — fuse3 install may have failed" \
    "sudo pacman -S fuse3 && re-run"
fi

info "rclone:      $RCLONE_BIN"
info "fusermount:  $FUSERMOUNT_BIN"

success "Packages installed"

# =============================================================================
# STEP 3 — INSTALL rmpc
# =============================================================================
step_header "Installing rmpc (terminal music player UI)"

info "Downloading official prebuilt rmpc binary from GitHub..."
echo ""

# Architecture-aware download
case "$ARCH_MACHINE" in
  x86_64)  RMPC_ARCH="x86_64-unknown-linux-gnu" ;;
  aarch64) RMPC_ARCH="aarch64-unknown-linux-gnu" ;;
  *)
    fail "rmpc" "Unsupported architecture: $ARCH_MACHINE" \
      "Install rmpc manually: https://github.com/mierak/rmpc/releases"
    ;;
esac

RMPC_TMP=$(mktemp -d)
RMPC_TARBALL="$RMPC_TMP/rmpc.tar.gz"
RMPC_URL="https://github.com/mierak/rmpc/releases/download/v0.11.0/rmpc-v0.11.0-${RMPC_ARCH}.tar.gz"

sudo rm -f /usr/local/bin/rmpc

if ! curl -fLS --progress-bar -o "$RMPC_TARBALL" "$RMPC_URL"; then
  rm -rf "$RMPC_TMP"
  fail "rmpc download" "curl failed — check internet connection" \
    "Check: https://github.com/mierak/rmpc/releases"
fi

if ! file "$RMPC_TARBALL" | grep -q "gzip compressed"; then
  rm -rf "$RMPC_TMP"
  fail "rmpc download" "File is not a valid gzip archive (got HTML 404?)" \
    "Check: https://github.com/mierak/rmpc/releases"
fi

if ! tar -xzf "$RMPC_TARBALL" -C "$RMPC_TMP"; then
  rm -rf "$RMPC_TMP"
  fail "rmpc extract" "tar extraction failed" "Re-run: bash scripts/setup-arch.sh"
fi

sudo mv "$RMPC_TMP/rmpc" /usr/local/bin/rmpc
sudo chmod +x /usr/local/bin/rmpc
rm -rf "$RMPC_TMP"

RMPC_VERSION=$(rmpc --version 2>&1 || echo "unknown")
success "rmpc installed: $RMPC_VERSION"

# =============================================================================
# STEP 4 — GOOGLE DRIVE FOLDER
# =============================================================================
step_header "Where is your music on Google Drive?"

echo -e "  ${DIM}Example 1:${RESET} Music in a folder called ${BOLD}Music${RESET}"
echo -e "             Drive / ${BOLD}Music${RESET} / song.mp3  →  type: ${BOLD}Music${RESET}"
echo ""
echo -e "  ${DIM}Example 2:${RESET} Music at the root of Drive"
echo -e "             Drive / song.mp3  →  press ${BOLD}Enter${RESET} (leave blank)"
echo ""
echo -e "  ${DIM}Example 3:${RESET} Custom subfolder"
echo -e "             Drive / ${BOLD}MyMusic${RESET} / song.mp3  →  type: ${BOLD}MyMusic${RESET}"
echo ""

GDRIVE_SUBFOLDER=$(ask_input "Folder name on Drive (Enter = root):")

if [[ -z "$GDRIVE_SUBFOLDER" ]]; then
  RCLONE_SOURCE="gdrive:"
  info "Will mount: root of your Google Drive"
else
  RCLONE_SOURCE="gdrive:${GDRIVE_SUBFOLDER}"
  info "Will mount: Google Drive / $GDRIVE_SUBFOLDER"
fi

success "Drive path: $RCLONE_SOURCE"

# =============================================================================
# STEP 5 — RCLONE AUTH
# =============================================================================
step_header "Connecting to Google Drive (rclone config)"

side_panel "What to type at each rclone prompt" \
  "${BOLD}n${RESET}        → new remote" \
  "${BOLD}gdrive${RESET}   → name it exactly this" \
  "${BOLD}drive${RESET}    → pick Google Drive from list" \
  "${BOLD}Enter${RESET}    → client_id (blank)" \
  "${BOLD}Enter${RESET}    → client_secret (blank)" \
  "${BOLD}1${RESET}        → scope: full access" \
  "${BOLD}Enter${RESET}    → root_folder_id (blank)" \
  "${BOLD}Enter${RESET}    → service_account_file (blank)" \
  "${BOLD}n${RESET}        → edit advanced config? No" \
  "${BOLD}y${RESET}        → use web browser? Yes (browser will open)" \
  "${BOLD}n${RESET}        → configure as shared drive? No" \
  "${BOLD}y${RESET}        → keep this remote? Yes  ← IMPORTANT" \
  "${BOLD}q${RESET}        → quit"

echo -e "  ${YELLOW}⚠  After logging in, press 'y' to KEEP the remote.${RESET}"
echo ""

if ask "Start Google Drive connection now?"; then
  rclone config

  if ! rclone lsd gdrive: &>/dev/null; then
    fail "Google Drive" \
      "Cannot reach 'gdrive:' — remote not saved correctly" \
      "Re-run rclone config, press y to keep the remote, then re-run this script."
  fi
  success "Google Drive connected"
else
  warn "Skipped. Run 'rclone config' manually, then re-run this script."
fi

# =============================================================================
# STEP 6 — SYSTEMD MOUNT SERVICE
# =============================================================================
step_header "Setting up auto-mount service"

info "Creating music folders..."
mkdir -p "$HOME_DIR/Music/gdrive" "$HOME_DIR/Music/playlists"
success "Created: ~/Music/gdrive and ~/Music/playlists"

info "Writing systemd service..."
mkdir -p "$HOME_DIR/.config/systemd/user"

# Unmount any stuck fuse mount from a previous run
fusermount3 -u "$HOME_DIR/Music/gdrive" 2>/dev/null || \
  fusermount  -u "$HOME_DIR/Music/gdrive" 2>/dev/null || true

cat > "$HOME_DIR/.config/systemd/user/rclone-gdrive.service" << EOF
[Unit]
Description=rclone Google Drive mount
After=network-online.target
Wants=network-online.target

[Service]
# Type=simple: rclone on Arch is not compiled with sd_notify support.
# Type=notify would cause systemd to kill the process before the mount stabilises.
Type=simple
ExecStart=${RCLONE_BIN} mount ${RCLONE_SOURCE} ${HOME_DIR}/Music/gdrive \\
  --vfs-cache-mode full \\
  --vfs-cache-max-size 500M \\
  --vfs-cache-max-age 1h \\
  --vfs-cache-poll-interval 1m \\
  --buffer-size 32M \\
  --dir-cache-time 72h
ExecStop=${FUSERMOUNT_BIN} -u ${HOME_DIR}/Music/gdrive
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user stop rclone-gdrive.service 2>/dev/null || true

if ! systemctl --user enable --now rclone-gdrive.service 2>&1; then
  fail "Auto-mount service" \
    "rclone-gdrive.service failed to start" \
    "Run: journalctl --user -u rclone-gdrive -n 30"
fi

sleep 3

if ! ls "$HOME_DIR/Music/gdrive" &>/dev/null; then
  fail "Drive mount" \
    "~/Music/gdrive is empty or not mounted" \
    "Run: systemctl --user status rclone-gdrive"
fi

FILE_COUNT=$(ls "$HOME_DIR/Music/gdrive" | wc -l)
success "Google Drive mounted — $FILE_COUNT items visible"

# =============================================================================
# STEP 7 — MPD CONFIG
# =============================================================================
step_header "Configuring MPD (Music Player Daemon)"

AUDIO_OUTPUT_BLOCK=""
if [[ "$AUDIO_TYPE" == "pipewire" ]]; then
  AUDIO_OUTPUT_BLOCK='audio_output {
    type "pipewire"
    name "PipeWire"
}'
else
  AUDIO_OUTPUT_BLOCK='audio_output {
    type "pulse"
    name "PulseAudio"
}'
fi

info "Audio output: $AUDIO_TYPE"
mkdir -p "$HOME_DIR/.local/share/mpd" "$HOME_DIR/.config/mpd"

cat > "$HOME_DIR/.config/mpd/mpd.conf" << EOF
music_directory    "$HOME_DIR/Music/gdrive"
playlist_directory "$HOME_DIR/Music/playlists"
db_file            "$HOME_DIR/.local/share/mpd/database"
log_file           "$HOME_DIR/.local/share/mpd/log"
state_file         "$HOME_DIR/.local/share/mpd/state"
sticker_file       "$HOME_DIR/.local/share/mpd/sticker.sql"

$AUDIO_OUTPUT_BLOCK

audio_output {
    type   "fifo"
    name   "fifo"
    path   "/tmp/mpd.fifo"
    format "44100:16:2"
}
EOF

# NOTE: On Arch, MPD is NOT enabled as a system service by default.
# The user service starts cleanly with no conflict.
systemctl --user stop mpd 2>/dev/null || true

if ! systemctl --user enable --now mpd 2>&1; then
  fail "MPD service" "MPD failed to start" \
    "Check: systemctl --user status mpd && cat $HOME_DIR/.local/share/mpd/log"
fi

sleep 1

MPD_STATUS=$(systemctl --user is-active mpd 2>/dev/null || echo "failed")
if [[ "$MPD_STATUS" != "active" ]]; then
  fail "MPD service" "MPD not running (status: $MPD_STATUS)" \
    "cat $HOME_DIR/.local/share/mpd/log"
fi

success "MPD running ($AUDIO_TYPE)"

# =============================================================================
# STEP 8 — rmpc + cava CONFIG
# =============================================================================
step_header "Configuring rmpc and cava"

info "Writing rmpc config..."
mkdir -p "$HOME_DIR/.config/rmpc"

cat > "$HOME_DIR/.config/rmpc/config.ron" << 'RMPC_EOF'
#![enable(implicit_some)]
#![enable(unwrap_newtypes)]
#![enable(unwrap_variant_newtypes)]
(
    address: "127.0.0.1:6600",
    volume_step: 5,
    scrolloff: 3,
    max_fps: 60,
    enable_mouse: true,
    enable_config_hot_reload: true,

    album_art: (
        method: Auto,
        max_size_px: (width: 1200, height: 1200),
        vertical_align: Center,
        horizontal_align: Center,
    ),

    cava: (
        framerate: 60,
        autosens: true,
        sensitivity: 130,
        input: (
            method: Fifo,
            source: "/tmp/mpd.fifo",
            sample_rate: 44100,
            channels: 2,
            sample_bits: 16,
        ),
        smoothing: (
            noise_reduction: 77,
            monstercat: false,
            waves: false,
        ),
    ),

    search: (
        case_sensitive: false,
        mode: Contains,
        tags: [
            (value: "any",    label: "Any Tag"),
            (value: "artist", label: "Artist"),
            (value: "album",  label: "Album"),
            (value: "title",  label: "Title"),
            (value: "genre",  label: "Genre"),
        ],
    ),

    keybinds: (
        global: {
            "p":         TogglePause,
            "s":         Stop,
            ">":         NextTrack,
            "<":         PreviousTrack,
            "f":         SeekForward,
            "b":         SeekBack,
            ",":         VolumeDown,
            ".":         VolumeUp,
            "1":         SwitchToTab("Queue"),
            "2":         SwitchToTab("Directories"),
            "3":         SwitchToTab("Artists"),
            "4":         SwitchToTab("Albums"),
            "5":         SwitchToTab("Playlists"),
            "6":         SwitchToTab("Search"),
            "F":         SwitchToTab("Search"),
            "<Tab>":     NextTab,
            "<S-Tab>":   PreviousTab,
            "r":         ToggleRepeat,
            "z":         ToggleRandom,
            "q":         Quit,
            "?":         ShowHelp,
            "I":         ShowCurrentSongInfo,
        },
        navigation: {
            "j":         Down,
            "k":         Up,
            "h":         Left,
            "l":         Right,
            "g":         Top,
            "G":         Bottom,
            "<CR>":      Confirm,
            "a":         Add,
            "d":         Delete,
            "/":         EnterSearch,
            "<Esc>":     Close,
            "<C-c>":     Close,
        },
        queue: {
            "<CR>":      Play,
            "d":         Delete,
            "D":         DeleteAll,
        },
    ),

    tabs: [
        (
            name: "Queue",
            border_type: None,
            pane: Split(
                direction: Horizontal,
                panes: [
                    (
                        size: "30%",
                        borders: "RIGHT",
                        pane: Split(
                            direction: Vertical,
                            panes: [
                                (size: "100%", pane: Pane(AlbumArt)),
                                (size: "8",    pane: Pane(Lyrics)),
                            ],
                        ),
                    ),
                    (
                        size: "100%",
                        pane: Split(
                            direction: Vertical,
                            panes: [
                                (size: "100%", pane: Pane(Queue)),
                                (size: "6", borders: "TOP", pane: Pane(Cava)),
                            ],
                        ),
                    ),
                ],
            ),
        ),
        (name: "Directories", border_type: None, pane: Pane(Directories)),
        (name: "Artists",     border_type: None, pane: Pane(Artists)),
        (name: "Albums",      border_type: None, pane: Pane(Albums)),
        (name: "Playlists",   border_type: None, pane: Pane(Playlists)),
        (name: "Search",      border_type: None, pane: Pane(Search)),
    ],
)
RMPC_EOF

success "rmpc configured"

info "Writing cava config..."
mkdir -p "$HOME_DIR/.config/cava"

cat > "$HOME_DIR/.config/cava/config" << 'CAVA_EOF'
[general]
bars = 50
framerate = 60

[input]
method = fifo
source = /tmp/mpd.fifo
sample_rate = 44100
sample_bits = 16
channels = 2

[color]
gradient = 1
gradient_color_1 = '#00e5a0'
gradient_color_2 = '#00aaff'

[smoothing]
noise_reduction = 77
CAVA_EOF

success "cava configured"

# =============================================================================
# STEP 9 — ALIASES + HELPER SCRIPTS
# =============================================================================
step_header "Installing helper commands"

mkdir -p "$HOME_DIR/scripts"

cat > "$HOME_DIR/scripts/mpd-update-watch.sh" << 'WATCHEOF'
#!/usr/bin/env bash
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

echo -e "\n  ${BOLD}Rescanning Google Drive music library...${RESET}\n"

BEFORE=$(mpc stats 2>/dev/null | awk '/Songs:/{print $2}')
BEFORE=${BEFORE:-0}
echo -e "  ${DIM}Songs before: $BEFORE${RESET}"
echo -ne "  ${CYAN}Scanning...${RESET}"

mpc update > /dev/null 2>&1
START=$(date +%s)
SPINNER='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
i=0

while mpc status 2>/dev/null | grep -q "Updating"; do
  CURRENT=$(mpc stats 2>/dev/null | awk '/Songs:/{print $2}')
  CURRENT=${CURRENT:-0}
  ELAPSED=$(( $(date +%s) - START ))
  SPIN_CHAR="${SPINNER:$(( i % 10 )):1}"
  printf "\r  %s Scanning...  ${BOLD}%d songs${RESET}  ${DIM}%ds${RESET}   " \
    "$SPIN_CHAR" "$CURRENT" "$ELAPSED"
  i=$(( i + 1 ))
  sleep 0.1
done

sleep 0.3
AFTER=$(mpc stats 2>/dev/null | awk '/Songs:/{print $2}')
AFTER=${AFTER:-0}
ELAPSED=$(( $(date +%s) - START ))
NEW=$(( AFTER - BEFORE ))

printf "\r                                                    \r"

if [[ $NEW -gt 0 ]]; then
  echo -e "  ${GREEN}✓${RESET} Done in ${ELAPSED}s"
  echo -e "  ${GREEN}+${NEW} new songs found${RESET}  (${BOLD}${AFTER} total${RESET})\n"
elif [[ $NEW -lt 0 ]]; then
  REMOVED=$(( BEFORE - AFTER ))
  echo -e "  ${GREEN}✓${RESET} Done in ${ELAPSED}s"
  echo -e "  ${YELLOW}-${REMOVED} songs removed${RESET}  (${BOLD}${AFTER} total${RESET})\n"
else
  echo -e "  ${GREEN}✓${RESET} Done in ${ELAPSED}s — ${BOLD}no changes${RESET}  (${AFTER} songs total)\n"
fi
WATCHEOF

chmod +x "$HOME_DIR/scripts/mpd-update-watch.sh"
success "mpd-update-watch script created"

info "Adding shell aliases..."

ALIASES='
# gdrive-music aliases
alias mpd-update='"'"'~/scripts/mpd-update-watch.sh'"'"'
alias music-status='"'"'systemctl --user status rclone-gdrive mpd'"'"'
alias music-cache='"'"'du -sh ~/.cache/rclone/ 2>/dev/null || echo "No cache yet"'"'"'
alias music-clear-cache='"'"'systemctl --user stop rclone-gdrive && rm -rf ~/.cache/rclone/vfs/ && systemctl --user start rclone-gdrive && echo "Cache cleared"'"'"'

music() {
  if [[ "${1:-}" == "--cava" ]]; then
    if command -v ghostty &>/dev/null; then
      ghostty -- cava &
    elif command -v kitty &>/dev/null; then
      kitty --detach cava &
    elif command -v alacritty &>/dev/null; then
      alacritty -e cava &
    elif command -v gnome-terminal &>/dev/null; then
      gnome-terminal -- cava &
    elif command -v xterm &>/dev/null; then
      xterm -e cava &
    else
      echo "No terminal found for cava. Install ghostty or kitty."
      return 1
    fi
    sleep 0.3
  fi
  rmpc
}
'

if ! grep -q "gdrive-music aliases" "$HOME_DIR/.bashrc" 2>/dev/null; then
  printf '%s\n' "$ALIASES" >> "$HOME_DIR/.bashrc"
  success "Aliases added to ~/.bashrc"
else
  success "Aliases already in ~/.bashrc — skipped"
fi

if [ -f "$HOME_DIR/.zshrc" ]; then
  if ! grep -q "gdrive-music aliases" "$HOME_DIR/.zshrc" 2>/dev/null; then
    printf '%s\n' "$ALIASES" >> "$HOME_DIR/.zshrc"
    success "Aliases added to ~/.zshrc"
  fi
fi

if [ -f "$HOME_DIR/.config/fish/config.fish" ]; then
  FISH_CONF="$HOME_DIR/.config/fish/config.fish"
  if ! grep -q "gdrive-music aliases" "$FISH_CONF" 2>/dev/null; then
    cat >> "$FISH_CONF" << 'FISH_EOF'

# gdrive-music aliases
alias mpd-update='~/scripts/mpd-update-watch.sh'
alias music-status='systemctl --user status rclone-gdrive mpd'
alias music-cache='du -sh ~/.cache/rclone/ 2>/dev/null || echo "No cache yet"'
alias music-clear-cache='systemctl --user stop rclone-gdrive && rm -rf ~/.cache/rclone/vfs/ && systemctl --user start rclone-gdrive && echo "Cache cleared"'

function music
  if test "$argv[1]" = "--cava"
    ghostty -- cava & or kitty --detach cava &
    sleep 0.3
  end
  rmpc
end
FISH_EOF
    success "Aliases added to ~/.config/fish/config.fish"
  fi
fi

# =============================================================================
# FIRST LIBRARY SCAN
# =============================================================================
header
echo -e "  ${BOLD}${GREEN}All steps completed!${RESET}"
echo ""
divider
echo ""
echo -e "  ${BOLD}Running first library scan...${RESET}"
echo -e "  ${DIM}Reads song metadata from your Drive. Can take a few minutes.${RESET}"
echo ""

"$HOME_DIR/scripts/mpd-update-watch.sh"

# =============================================================================
# DONE
# =============================================================================
echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "  ${GREEN}║                                                          ║${RESET}"
echo -e "  ${GREEN}║   🎵  gdrive-music is ready!                             ║${RESET}"
echo -e "  ${GREEN}║                                                          ║${RESET}"
echo -e "  ${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${BOLD}Commands:${RESET}"
echo ""
echo -e "  ${CYAN}music${RESET}               → launch rmpc"
echo -e "  ${CYAN}music --cava${RESET}        → rmpc + cava in a new window"
echo -e "  ${CYAN}mpd-update${RESET}          → rescan Drive for new songs"
echo -e "  ${CYAN}music-status${RESET}        → check services"
echo -e "  ${CYAN}music-cache${RESET}         → see SSD cache usage"
echo -e "  ${CYAN}music-clear-cache${RESET}   → free SSD cache"
echo ""
divider
echo ""
echo -e "  ${DIM}Reload shell:${RESET}  ${BOLD}source ~/.bashrc${RESET}"
echo -e "  ${DIM}Or open a new terminal window.${RESET}"
echo ""
