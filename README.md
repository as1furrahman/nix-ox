# NixOS — Asus Zenbook S 13 OLED (UM5302TA)

Minimal NixOS with Hyprland, Home Manager, Ambxst shell, and OLED-optimized defaults.

---

## Hardware

| Component | Model |
|-----------|-------|
| CPU | AMD Ryzen 7 6800U (Zen 3+, Rembrandt) |
| GPU | AMD Radeon 680M (RDNA 2, integrated) |
| Display | 13.3″ 2880×1800 OLED, 60 Hz |
| RAM | 16 GB LPDDR5 (soldered) |
| SSD | Samsung 990 Pro 1 TB (NVMe) |
| Wi-Fi/BT | MediaTek MT7922 (RZ616) |
| Audio | Realtek ALC294 |

---

## File Map

```
/etc/nixos/
├── flake.nix                   # Flake entry — nixpkgs-unstable + Home Manager
├── configuration.nix           # System: boot, kernel, services, snapper, fonts
├── hardware-configuration.nix  # Auto-generated (nixos-generate-config)
├── hardware-tweaks.nix         # Zenbook-specific: GPU, CPU, TLP, sensors
├── hyprland.nix                # System-level: Hyprland binary, portals, env vars
└── home.nix                    # User-level: packages, Hyprland config, theming, shell
```

**What lives where:**

| Concern | File | Why |
|---------|------|-----|
| GRUB, kernel, kernel params | configuration.nix | Boot-level, needs root |
| PipeWire, Bluetooth, NetworkManager | configuration.nix | System daemons |
| Snapper, Btrfs scrub, fstrim | configuration.nix | Root filesystem operations |
| Fonts | configuration.nix | System-wide font cache |
| AMD GPU/CPU, TLP, firmware | hardware-tweaks.nix | Hardware-specific tuning |
| Hyprland binary, XDG portals | hyprland.nix | System programs |
| Wayland session variables | hyprland.nix | Must be set before user session |
| User packages (ripgrep, mpv, etc.) | home.nix | User-scoped, Home Manager |
| Hyprland settings, keybinds, rules | home.nix | Per-user Hyprland config |
| hypridle | home.nix | HM service module |
| Ghostty, Git, Bash, Firefox | home.nix | User-level programs |
| GTK/Qt theme, cursors | home.nix | User environment |
| Ambxst autostart | home.nix | User session exec-once |

---

## Partition Layout

```
Device            Size    Type          Mount
/dev/nvme0n1p1    1 GiB   EFI (ef00)   /boot
/dev/nvme0n1p2    20 GiB  swap (8200)  [swap]
/dev/nvme0n1p3    ~931 G  Btrfs (8300) /
```

20 GiB swap enables hibernate with 16 GB RAM.

### Btrfs Subvolumes

```
Subvolume    Mount Point    Snapshotted?
@            /              Yes (snapper: root)
@home        /home          Yes (snapper: home)
@nix         /nix           No  (reproducible via flake)
@log         /var/log       No  (ephemeral)
@snapshots   /.snapshots    —   (snapshot storage for root)
```

Mount options for all: `compress=zstd:1,noatime,ssd,discard=async,space_cache=v2`

---

## Installation — Step by Step

### 1. Boot NixOS Minimal ISO

Download from https://nixos.org/download — use the minimal ISO. Boot from USB.

### 2. Partition the Drive

```bash
sudo gdisk /dev/nvme0n1
```

| Partition | Command | Size | Type Code |
|-----------|---------|------|-----------|
| EFI | `n`, `+1G` | 1 GiB | `ef00` |
| Swap | `n`, `+20G` | 20 GiB | `8200` |
| Root | `n`, (default) | Remaining | `8300` |

Write with `w`.

### 3. Format Partitions

```bash
sudo mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
sudo mkswap -L swap /dev/nvme0n1p2
sudo mkfs.btrfs -L nixos -f /dev/nvme0n1p3
```

### 4. Create Btrfs Subvolumes

```bash
sudo mount /dev/nvme0n1p3 /mnt

sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@nix
sudo btrfs subvolume create /mnt/@log
sudo btrfs subvolume create /mnt/@snapshots

sudo umount /mnt
```

### 5. Mount Everything

```bash
OPTS="compress=zstd:1,noatime,ssd,discard=async,space_cache=v2"

sudo mount -o subvol=@,$OPTS /dev/nvme0n1p3 /mnt
sudo mkdir -p /mnt/{home,nix,var/log,.snapshots,boot}

sudo mount -o subvol=@home,$OPTS      /dev/nvme0n1p3 /mnt/home
sudo mount -o subvol=@nix,$OPTS       /dev/nvme0n1p3 /mnt/nix
sudo mount -o subvol=@log,$OPTS       /dev/nvme0n1p3 /mnt/var/log
sudo mount -o subvol=@snapshots,$OPTS /dev/nvme0n1p3 /mnt/.snapshots
sudo mount /dev/nvme0n1p1 /mnt/boot

sudo swapon /dev/nvme0n1p2
```

### 6. Create Snapper Snapshot Subvolumes

Snapper requires a `.snapshots` subvolume inside each managed subvolume:

```bash
# For /home snapshots
sudo mkdir -p /mnt/home/.snapshots
sudo btrfs subvolume create /mnt/home/.snapshots
```

The root `/.snapshots` is already handled by `@snapshots`.

### 7. Generate Hardware Config

```bash
sudo nixos-generate-config --root /mnt
```

This creates `/mnt/etc/nixos/hardware-configuration.nix` — **do not overwrite this file**, it is auto-generated for your specific hardware.

### 8. Copy Configuration Files

```bash
# Copy all provided .nix files into /mnt/etc/nixos/
# (flake.nix, configuration.nix, hardware-tweaks.nix, hyprland.nix, home.nix)

# IMPORTANT: Do NOT overwrite hardware-configuration.nix — it was
# generated in the previous step and is unique to your machine.
```

### 9. Install

```bash
cd /mnt/etc/nixos
sudo nixos-install --flake .#zenbook
```

You will be prompted to set the root password.

### 10. Reboot

```bash
sudo reboot
```

---

## Post-Install Setup

### Set User Password

```bash
sudo passwd asif
```

### Install Ambxst

Ambxst is not in nixpkgs — install imperatively from its flake:

```bash
nix profile add github:Axenide/Ambxst
```

### Create Screenshots Directory

The screenshot keybinds save to `~/Pictures/Screenshots/`:

```bash
mkdir -p ~/Pictures/Screenshots
```

### Start Hyprland

From the TTY after login:

```bash
Hyprland
```

On subsequent boots, simply log in at the TTY and type `Hyprland`.

### Edit Git Identity

Open `/etc/nixos/home.nix` and update:

```nix
programs.git = {
  userName = "Your Name";
  userEmail = "your@email.com";
};
```

Then rebuild:

```bash
rebuild
```

---

## Keybindings Reference

### Window Management

| Keys | Action |
|------|--------|
| `SUPER + C` | Close window |
| `SUPER + SHIFT + Escape` | Exit Hyprland |
| `SUPER + Space` | Toggle floating |
| `SUPER + P` | Pseudo-tile |
| `SUPER + SHIFT + D` | Toggle split direction |
| `SUPER + F` | Fullscreen |
| `SUPER + SHIFT + F` | Fake fullscreen |
| `SUPER + CTRL + F` | Maximize |
| `SUPER + Y` | Pin floating window |
| `SUPER + G` | Center floating window |

### Focus (HJKL + Arrows)

| Keys | Action |
|------|--------|
| `SUPER + H / ←` | Focus left |
| `SUPER + L / →` | Focus right |
| `SUPER + K / ↑` | Focus up |
| `SUPER + J / ↓` | Focus down |

### Move Tiled Windows

| Keys | Action |
|------|--------|
| `SUPER + SHIFT + H / ←` | Move left |
| `SUPER + SHIFT + L / →` | Move right |
| `SUPER + SHIFT + K / ↑` | Move up |
| `SUPER + SHIFT + J / ↓` | Move down |

### Resize (hold to repeat)

| Keys | Action |
|------|--------|
| `SUPER + CTRL + H / ←` | Shrink width |
| `SUPER + CTRL + L / →` | Grow width |
| `SUPER + CTRL + K / ↑` | Shrink height |
| `SUPER + CTRL + J / ↓` | Grow height |

### Move Floating (hold to repeat)

| Keys | Action |
|------|--------|
| `SUPER + ALT + H / ←` | Move left |
| `SUPER + ALT + L / →` | Move right |
| `SUPER + ALT + K / ↑` | Move up |
| `SUPER + ALT + J / ↓` | Move down |

### Layout Switching

| Keys | Action |
|------|--------|
| `SUPER + Tab` | Switch to Dwindle |
| `SUPER + SHIFT + Tab` | Switch to Master |

### Workspaces (1–10)

| Keys | Action |
|------|--------|
| `SUPER + 1–9` | Go to workspace 1–9 |
| `SUPER + 0` | Go to workspace 10 |
| `SUPER + SHIFT + 1–9, 0` | Move window to workspace |
| `SUPER + Z` | Previous workspace |
| `SUPER + X` | Next active workspace |
| `SUPER + Scroll` | Cycle workspaces |

### Programs

| Keys | Action |
|------|--------|
| `SUPER + Return` | Terminal (Ghostty) |
| `SUPER + SHIFT + Return` | Floating terminal |
| `SUPER + E` | File manager (Thunar) |
| `SUPER + SHIFT + E` | Floating file manager |
| `SUPER + W` | Browser (Firefox) |
| `SUPER + SHIFT + W` | Private browser window |

### Ambxst Shell

| Keys | Action |
|------|--------|
| `SUPER + D` | Dashboard / App launcher |
| `SUPER + A` | AI assistant |
| `SUPER + ,` | Wallpaper selector |
| `SUPER + SHIFT + B` | Reload shell CSS |
| `SUPER + ALT + B` | Restart shell |
| `SUPER + CTRL + B` | Toggle bar |

### Screenshots

| Keys | Action |
|------|--------|
| `Print` | Area → save + copy |
| `SHIFT + Print` | Fullscreen → save + copy |
| `SUPER + SHIFT + S` | Area → copy only |

### System

| Keys | Action |
|------|--------|
| `SUPER + CTRL + L` | Lock screen |
| Media keys | Volume, brightness, playback |

### Mouse

| Keys | Action |
|------|--------|
| `SUPER + Left Click` | Drag window |
| `SUPER + Right Click` | Resize window |
| 3-finger swipe | Switch workspace |

---

## OLED Protection

This config includes multiple OLED burn-in mitigations:

| Mechanism | Setting | Effect |
|-----------|---------|--------|
| Variable frame rate | `misc.vfr = true` | Reduces static pixel refresh |
| DPMS off at 8 min | hypridle listener | Turns off all pixels completely |
| Dim at 3 min | hypridle listener | Drops brightness to 10% |
| Suspend at 15 min | hypridle listener | Full system sleep |
| Ambxst auto-hide | Overlay panel | Not a persistent status bar |
| Dark theme | GTK/Qt Adwaita-dark | Fewer lit pixels on OLED |
| Dim inactive | `dim_inactive = true` | Reduces brightness on unfocused windows |

---

## Daily Operations

### Rebuild After Config Changes

```bash
rebuild
# Alias for: sudo nixos-rebuild switch --flake /etc/nixos#zenbook
```

### Test Changes Without Committing

```bash
rebuild-test
# Alias for: sudo nixos-rebuild test --flake /etc/nixos#zenbook
```

### Update All Inputs (nixpkgs + Home Manager)

```bash
update
# Alias for: cd /etc/nixos && sudo nix flake update && rebuild
```

### Rollback

```bash
sudo nixos-rebuild switch --rollback
```

Or select previous generation from GRUB at boot.

### Garbage Collect Old Generations

```bash
gc
# Alias for: sudo nix-collect-garbage -d
```

---

## Snapper — Btrfs Snapshots

### Create Manual Snapshot

```bash
sudo snapper -c root create --description "before major update"
sudo snapper -c home create --description "before major update"
```

### List Snapshots

```bash
sudo snapper -c root list
sudo snapper -c home list
```

### Restore from Snapshot

```bash
# Compare changes between snapshots
sudo snapper -c root diff 1..2

# Restore a single file from snapshot N
sudo snapper -c root undochange 1..2 /path/to/file

# Full rollback requires booting from snapshot subvolume
# (advanced — see NixOS + Btrfs rollback guides)
```

### Automatic Schedule

Configured via Snapper timeline (both `root` and `home`):

| Interval | Retained |
|----------|----------|
| Hourly | 10 |
| Daily | 7 |
| Weekly | 4 |
| Monthly | 6 |
| Yearly | 0 |

Boot snapshots are created automatically (`snapshotRootOnBoot = true`).

---

## Filesystem Health

### Btrfs Scrub (runs weekly automatically)

```bash
# Manual trigger
sudo btrfs scrub start /
sudo btrfs scrub status /
```

### Check Compression Ratio

```bash
sudo compsize /
```

### SMART Disk Health

```bash
sudo smartctl -a /dev/nvme0n1
```

---

## Samsung 990 Pro NVMe Notes

The firmware sleep bug is mitigated by the kernel parameter:

```
nvme_core.default_ps_max_latency_us=5500
```

This is set in `configuration.nix` under `boot.kernelParams`. TRIM is handled two ways:

1. **Btrfs mount option** `discard=async` — realtime background TRIM
2. **fstrim.service** — weekly periodic TRIM (belt-and-suspenders)

Samsung has released firmware updates that may fully fix the bug. Check with:

```bash
sudo smartctl -a /dev/nvme0n1 | grep "Firmware"
```

---

## Troubleshooting

### Wi-Fi drops on MT7922

Uncomment the ASPM disable line in `hardware-tweaks.nix`:

```nix
boot.kernelParams = lib.mkAfter [ "mt7921e.disable_aspm=Y" ];
```

### Cursor invisible or flickering

Already mitigated by:
- `WLR_NO_HARDWARE_CURSORS=1` (hyprland.nix)
- `cursor.no_hardware_cursors = true` (home.nix)

### Scaling looks wrong

Adjust the monitor line in `home.nix`:

```nix
monitor = [ "eDP-1, 2880x1800@60, 0x0, 1.5" ];  # try 1.5 instead of 1.333
```

### Ambxst not starting

Verify it's installed:

```bash
which ambxst
# If not found:
nix profile add github:Axenide/Ambxst
```

Check logs:

```bash
journalctl --user -u ambxst -b
```

### Build fails after flake update

```bash
# Roll back the flake.lock
cd /etc/nixos
git diff flake.lock   # if using git
sudo nixos-rebuild switch --rollback

# Or pin a specific nixpkgs commit in flake.nix:
# nixpkgs.url = "github:NixOS/nixpkgs/<commit-hash>";
```

### External monitor

Add a second monitor line in `home.nix`:

```nix
monitor = [
  "eDP-1, 2880x1800@60, 0x0, 1.333333"
  "HDMI-A-1, preferred, auto-right, 1"   # auto-detect external
];
```

---

## Configuration Design Choices

### Why Home Manager as NixOS Module (not standalone)?

- Single `sudo nixos-rebuild switch` deploys both system and user config
- No separate `home-manager switch` step
- `useGlobalPkgs = true` avoids evaluating nixpkgs twice (faster builds, less RAM)
- `useUserPackages = true` installs to per-user profile (clean separation)

### Why Axenide-style keybindings?

- `SUPER+C` close avoids conflict with `SUPER+Q` (used by some apps)
- HJKL navigation keeps hands on home row
- `SUPER+Space` for float toggle is ergonomic and widely familiar
- Modifier layers (SHIFT=move, CTRL=resize, ALT=float-move) are consistent

### Why neutral border colors?

Ambxst dynamically themes the entire desktop including wallpaper-adaptive colors. Hardcoded border colors would clash. The white/grey defaults are overridden by Ambxst at runtime.

### Why `hyprmon` was removed

`hyprmon` is not a standard nixpkgs package. For multi-monitor management, use `hyprctl monitors` and add monitor lines to `home.nix`, or use `nwg-displays` (available in nixpkgs).
