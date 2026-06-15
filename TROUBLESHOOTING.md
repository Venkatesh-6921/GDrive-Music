# Troubleshooting Guide

## Setup Fails

### rmpc download stops mid-way
The download timed out or GitHub was slow. Just re-run:
```bash
bash scripts/setup.sh
```
The script cleans up incomplete downloads automatically.

### RPMFusion install fails (Fedora)
RPMFusion is probably already enabled. This is harmless — the script continues.

### `rclone lsd gdrive:` returns nothing
You didn't save the remote at the end of `rclone config`.  
Re-run it and make sure you press `y` when asked "keep this remote?"
```bash
rclone config
```

---

## Drive Not Mounting

### `~/Music/gdrive` is empty after setup
```bash
# Check service status
systemctl --user status rclone-gdrive

# See full logs
journalctl --user -u rclone-gdrive -n 50

# Try mounting manually to see the real error
rclone mount gdrive:Music ~/Music/gdrive --vfs-cache-mode full
```

### `fusermount: fuse device not found`
FUSE isn't loaded. Run:
```bash
sudo modprobe fuse
```
Then restart the service:
```bash
systemctl --user restart rclone-gdrive
```

### Mount point busy / already mounted
```bash
fusermount3 -u ~/Music/gdrive    # Fedora
fusermount -u ~/Music/gdrive     # Ubuntu/Debian
systemctl --user restart rclone-gdrive
```

---

## MPD Issues

### MPD won't start
```bash
# Check the log
cat ~/.local/share/mpd/log

# Check status
systemctl --user status mpd
```

**Common cause on Ubuntu/Debian:** The system MPD service conflicts with the user one.
```bash
sudo systemctl stop mpd mpd.socket
sudo systemctl disable mpd mpd.socket
systemctl --user restart mpd
```

### No audio / PipeWire error
If you're on PulseAudio instead of PipeWire, edit `~/.config/mpd/mpd.conf`:

Change:
```
audio_output {
    type "pipewire"
    name "PipeWire"
}
```
To:
```
audio_output {
    type "pulse"
    name "PulseAudio"
}
```
Then:
```bash
systemctl --user restart mpd
```

---

## rmpc Issues

### rmpc opens but library is empty
MPD hasn't scanned your Drive yet:
```bash
mpd-update
# Wait for it to finish — can take 5-20 min for large libraries
mpc stats  # check song count
```

### rmpc crashes on startup / RON parse error
Your config file has a syntax error. Reset it:
```bash
rm ~/.config/rmpc/config.ron
bash scripts/setup.sh   # re-run just to regenerate config
```

### Album art not showing
Album art needs a Kitty-protocol terminal: **Ghostty**, **Kitty**, or **WezTerm**.  
It won't show in GNOME Terminal, xterm, or Alacritty.

---

## cava Issues

### cava shows nothing / flat line
MPD FIFO isn't being written to. Check:
```bash
ls -la /tmp/mpd.fifo        # should exist while MPD is running
systemctl --user status mpd
```
Make sure a song is actually playing, not just paused.

---

## rclone Token Expired

After 90 days of not using it, the Google token expires:
```bash
rclone config reconnect gdrive:
```
Then restart:
```bash
systemctl --user restart rclone-gdrive
```

---

## `music` command not found after setup

You need to reload your shell:
```bash
source ~/.bashrc    # or source ~/.zshrc
```
Or just open a new terminal window.

---

## Full Reset

If everything is broken and you want to start fresh:
```bash
bash scripts/uninstall.sh
# then
bash scripts/setup.sh
```
