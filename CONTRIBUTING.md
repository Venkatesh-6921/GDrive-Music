# Contributing to gdrive-music

Thank you for your interest in contributing! Please read this fully before
opening an issue or pull request.

---

## 🔒 Access Policy

**Direct repository access is not granted to external contributors.**

- Do NOT request collaborator or write access to this repo
- Do NOT expect your PR to be merged immediately — all PRs are reviewed first
- Only the project maintainer (@Venkatesh-6921) merges pull requests
- Maintainer reserves the right to close any PR without explanation

If you want to contribute, follow the fork-based workflow below.

---

## 🐛 Reporting Bugs

Before opening an issue:

1. Check [existing issues](https://github.com/Venkatesh-6921/gdrive-music/issues) — it may already be reported
2. Try the [troubleshooting guide](TROUBLESHOOTING.md)
3. Run the uninstall script and reinstall fresh

When opening an issue, include:

```
- Distro and version (e.g. Ubuntu 22.04, Fedora 44)
- Terminal emulator (e.g. Ghostty, GNOME Terminal)
- Which script you ran (setup.sh / setup-ubuntu.sh / etc.)
- The exact error message or screenshot
- Output of: systemctl --user status mpd rclone-gdrive
```

---

## 💡 Feature Requests

Open an issue with the `feature request` label. Describe:

- What you want
- Why it's useful
- Whether you're willing to implement it

Check the [roadmap in README](README.md#roadmap) first — it may already be planned.

---

## 🔧 Submitting a Pull Request

### Step 1 — Fork the repo

Click **Fork** on GitHub. Clone your fork:

```bash
git clone https://github.com/YOUR_USERNAME/gdrive-music
cd gdrive-music
```

### Step 2 — Create a branch

```bash
git checkout -b fix/describe-your-fix
# or
git checkout -b feat/describe-your-feature
```

Use clear branch names:
- `fix/ubuntu-mpd-conflict`
- `feat/arch-support`
- `docs/improve-troubleshooting`

### Step 3 — Make your changes

- Test your changes on your own machine before submitting
- If you're fixing a distro-specific bug, mention which distro you tested on
- Keep changes focused — one fix or feature per PR
- Don't bundle unrelated changes together

### Step 4 — Validate your script

If you changed any `.sh` file, run a syntax check:

```bash
bash -n scripts/setup.sh
bash -n scripts/uninstall.sh
```

It must pass with no errors before submitting.

### Step 5 — Push and open a PR

```bash
git add .
git commit -m "fix: describe what you fixed"
git push origin fix/describe-your-fix
```

Then open a Pull Request on GitHub.

**In your PR description, include:**
- What the problem was
- What you changed
- Which distro you tested on
- Screenshots or terminal output if relevant

---

## 📋 PR Rules

| Rule | Detail |
|------|--------|
| ✅ Fork-based only | No direct pushes to main |
| ✅ One thing per PR | Don't mix fixes and features |
| ✅ Tested locally | State your distro and test result |
| ✅ Syntax checked | `bash -n` must pass |
| ❌ No force pushes | Don't rewrite history on shared branches |
| ❌ No merging your own PR | Maintainer merges all PRs |
| ❌ No requesting access | Fork workflow only |

---

## 🌿 Branch Naming

| Type | Format | Example |
|------|--------|---------|
| Bug fix | `fix/short-description` | `fix/ubuntu-mpd-conflict` |
| Feature | `feat/short-description` | `feat/dropbox-support` |
| Docs | `docs/short-description` | `docs/arch-troubleshooting` |
| Script | `script/short-description` | `script/debian-cava-build` |

---

## ✅ What We Welcome

- Bug fixes for other distros (Ubuntu, Debian, Arch)
- Improvements to error messages
- Documentation fixes and additions
- Troubleshooting guide improvements
- New distro support scripts

## ❌ What We Won't Accept

- Rewrites of the core wizard UI without prior discussion
- Adding new tools to the stack without an open issue and agreement
- PRs that break Fedora support to fix another distro
- Unrelated changes bundled into one PR

---

## 📬 Questions

Open an issue with the `question` label.
Do not email or DM for support — GitHub issues keep everything public and searchable.

---

*Thanks for contributing. Every bug report and fix helps someone on a different distro.*
