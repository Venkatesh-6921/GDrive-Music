#!/usr/bin/env bash
# =============================================================================
# gdrive-music — Full Uninstall
# Removes: rmpc, rclone, mpd, cava + all configs, services, aliases
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

HOME_DIR="$HOME"

info()    { echo -e "  ${CYAN}→${RESET} $1"; }
success() { echo -e "  ${GREEN}✓${RESET} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $1"; }

clear
echo -e "${RED}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║          gdrive-music  —  Full Uninstall                ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "  ${BOLD}${RED}This will permanently remove:${RESET}"
echo ""
echo -e "  ${RED}•${RESET} rmpc binary (/usr/local/bin/rmpc)"
echo -e "  ${RED}•${RESET} rclone + Google Drive remote config"
echo -e "  ${RED}•${RESET} mpd, mpc, cava packages"
echo -e "  ${RED}•${RESET} All configs: ~/.config/{rmpc,mpd,cava,rclone}"
echo -e "  ${RED}•${RESET} systemd services: rclone-gdrive, mpd"
echo -e "  ${RED}•${RESET} MPD data: ~/.local/share/mpd"
echo -e "  ${RED}•${RESET} rclone VFS cache: ~/.cache/rclone"
echo -e "  ${RED}•${RESET} Music mount folder: ~/Music/gdrive"
echo -e "  ${RED}•${RESET} ~/scripts/mpd-update-watch.sh"
echo -e "  ${RED}•${RESET} gdrive-music aliases in ~/.bashrc / ~/.zshrc"
echo ""
echo -ne "  ${BOLD}Type 'yes' to confirm: ${RESET}"
read -r CONFIRM
echo ""

if [[ "$CONFIRM" != "yes" ]]; then
  echo -e "  ${YELLOW}Cancelled. Nothing was removed.${RESET}"
  exit 0
fi

echo ""

# ── Stop and disable services ─────────────────────────────────────────────────
info "Stopping services..."
for svc in mpd rclone-gdrive; do
  systemctl --user stop "$svc" 2>/dev/null || true
  systemctl --user disable "$svc" 2>/dev/null || true
done
systemctl --user daemon-reload 2>/dev/null || true
success "Services stopped"

# ── Unmount Drive ─────────────────────────────────────────────────────────────
if mountpoint -q "$HOME_DIR/Music/gdrive" 2>/dev/null; then
  info "Unmounting ~/Music/gdrive..."
  fusermount3 -u "$HOME_DIR/Music/gdrive" 2>/dev/null || \
  fusermount -u "$HOME_DIR/Music/gdrive" 2>/dev/null || \
  sudo umount "$HOME_DIR/Music/gdrive" 2>/dev/null || true
  success "Unmounted"
fi

# ── Remove service files ──────────────────────────────────────────────────────
info "Removing service files..."
rm -f "$HOME_DIR/.config/systemd/user/rclone-gdrive.service"
rm -f "$HOME_DIR/.config/systemd/user/mpd.service"
systemctl --user daemon-reload 2>/dev/null || true
success "Service files removed"

# ── Remove packages ───────────────────────────────────────────────────────────
info "Removing packages (mpd, mpc, cava, rclone)..."
if command -v dnf &>/dev/null; then
  sudo dnf remove -y mpd mpc cava rclone 2>/dev/null || true
elif command -v apt &>/dev/null; then
  sudo apt remove -y --purge mpd mpc cava rclone 2>/dev/null || true
  sudo apt autoremove -y 2>/dev/null || true
elif command -v pacman &>/dev/null; then
  sudo pacman -Rns --noconfirm mpd mpc cava rclone 2>/dev/null || true
fi
success "Packages removed"

# ── Remove rmpc binary ────────────────────────────────────────────────────────
info "Removing rmpc..."
sudo rm -f /usr/local/bin/rmpc
success "rmpc removed"

# ── Remove configs ────────────────────────────────────────────────────────────
info "Removing configs..."
rm -rf "$HOME_DIR/.config/rmpc"
rm -rf "$HOME_DIR/.config/mpd"
rm -rf "$HOME_DIR/.config/cava"
rm -rf "$HOME_DIR/.config/rclone"
success "Configs removed"

# ── Remove data and cache ─────────────────────────────────────────────────────
info "Removing MPD data..."
rm -rf "$HOME_DIR/.local/share/mpd"
success "MPD data removed"

info "Removing rclone VFS cache..."
rm -rf "$HOME_DIR/.cache/rclone"
success "Cache removed"

# ── Remove music folders ──────────────────────────────────────────────────────
info "Removing ~/Music/gdrive and ~/Music/playlists..."
rm -rf "$HOME_DIR/Music/gdrive"
rm -rf "$HOME_DIR/Music/playlists"
rmdir "$HOME_DIR/Music" 2>/dev/null && \
  info "Removed ~/Music (was empty)" || \
  warn "~/Music kept — has other files"
success "Music folders removed"

# ── Remove helper scripts ─────────────────────────────────────────────────────
info "Removing helper scripts..."
rm -f "$HOME_DIR/scripts/mpd-update-watch.sh"
rmdir "$HOME_DIR/scripts" 2>/dev/null && \
  info "Removed ~/scripts (was empty)" || \
  warn "~/scripts kept — has other files"
success "Scripts removed"

# ── Remove aliases from shell configs ─────────────────────────────────────────
info "Cleaning shell aliases..."
for rc in "$HOME_DIR/.bashrc" "$HOME_DIR/.zshrc"; do
  if [ -f "$rc" ] && grep -q "gdrive-music aliases" "$rc" 2>/dev/null; then
    # Remove block from marker to next blank line after the music() function
    sed -i '/# gdrive-music aliases/,/^}$/d' "$rc"
    success "Aliases removed from $rc"
  fi
done

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "  ${GREEN}║   ✓  Everything removed. Clean slate.                    ║${RESET}"
echo -e "  ${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${DIM}Reload shell:${RESET}  ${BOLD}source ~/.bashrc${RESET}"
echo -e "  ${DIM}Fresh install:${RESET} ${BOLD}bash scripts/setup.sh${RESET}"
echo ""
