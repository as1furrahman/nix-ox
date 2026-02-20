# NixOS — Asus Zenbook S 13 OLED (UM5302TA)

Declarative, reproducible NixOS configuration for the Asus Zenbook S 13 OLED, built around Hyprland and the Ambxst desktop shell. Optimized for OLED burn-in protection, AMD Ryzen 7 6800U power management, and a minimal yet fully-featured Wayland desktop.

---

## Hardware

| Component | Details |
|---|---|
| **Model** | Asus Zenbook S 13 OLED (UM5302TA) |
| **CPU** | AMD Ryzen 7 6800U (Zen 3+, 8C/16T) |
| **GPU** | AMD Radeon 680M (RDNA 2, integrated) |
| **Display** | 13.3" 2880×1800 OLED, 60 Hz |
| **RAM** | 16 GB LPDDR5 (soldered) |
| **Storage** | Samsung 990 Pro 1 TB NVMe (upgraded) |
| **Wi-Fi/BT** | MediaTek MT7922 (RZ616) |

---

## Architecture

```
flake.nix                  # Entry point — nixpkgs-unstable + Home Manager inputs
├── configuration.nix      # System: boot, networking, audio, bluetooth, fonts, services
├── hardware-configuration.nix  # Auto-generated — machine-specific, must be git-tracked for flakes
├── hardware-tweaks.nix    # Zenbook-specific: AMD GPU/CPU, TLP, NVMe, sensors
├── hyprland.nix           # System-level Hyprland: portals, dconf, session variables
└── home.nix               # User: packages, Hyprland settings, theming, keybinds, services
```

### Design Decisions

**Hyprland package management** — The NixOS module (`programs.hyprland.enable`) provides the Hyprland binary and portals at the system level. The Home Manager module is configured with `package = null; portalPackage = null` to use the system package, preventing version mismatches between system and user installs.

**Two-tier swap** — zram provides 8 GB of compressed in-RAM swap (priority 100) for everyday use with zero disk I/O. A 16 GiB on-disk swap partition (priority −2) serves as hibernate target and overflow. The kernel `resume=` parameter and `boot.resumeDevice` are configured for hibernate support.

**Theme propagation** — Dark mode is enforced through three layers: `GTK_THEME=Adwaita:dark` (environment variable for GTK2/3), `gtk-application-prefer-dark-theme` (GTK3/4 settings.ini), and `dconf: org/gnome/desktop/interface/color-scheme = "prefer-dark"` (libadwaita/GTK4 apps that only read dconf).

**Power management** — TLP handles CPU governor dynamically (performance on AC, powersave on battery). No static `cpuFreqGovernor` is set at the NixOS level to avoid conflicts. `amd_pstate=active` is passed as a kernel parameter for the AMD P-state driver.

**Ambxst as the sole shell** — Ambxst (Axenide's Quickshell-based desktop shell) provides the bar, launcher, notifications, clipboard manager, power menu, Wi-Fi/Bluetooth controls, and a built-in polkit agent. A polkit-gnome systemd service runs as a fallback for early-boot coverage or shell crashes.

**Display manager — greetd + tuigreet** — A minimal TUI-based login manager with no X11 dependency. The `initial_session` block auto-logs in on first boot (for seamless initial setup), while `default_session` presents tuigreet on subsequent logins. UWSM was evaluated but not adopted due to known bugs with `XDG_CURRENT_DESKTOP` misidentification; the Home Manager systemd integration (`wayland.windowManager.hyprland.systemd.enable = true`) handles session target activation instead.

**Visual foundation (Ambxst-synchronized)** — The Hyprland config provides the visual canvas that Ambxst paints on. Ambxst overrides border colors and some settings via IPC at launch, so the Nix config defines the pre-Ambxst baseline and the properties Ambxst doesn't touch:

- *Blur*: 4-pass, size-8 frosted glass with layer rules using `ignore_alpha` for clean Ambxst popup rendering
- *Gaps*: Inner 6, outer 14 — enough breathing room for Ambxst's floating bar and notification popups
- *Rounding*: 14px — matches Ambxst's own rounded UI elements
- *Borders*: 3px warm gradient (gold → peach, 45°) with `borderangle` loop animation. Ambxst overrides these with its wallpaper-derived palette
- *Shadows*: Wide (22px range), soft (power 2), with slight downward offset — optimized for OLED where true-black backgrounds swallow hard shadows
- *Animations*: Five purpose-built bezier curves (snappy, fluid, spring, ease, exit) with tighter durations than stock
- *Layer rules*: Explicit blur and alpha rules for `ambxst:*` namespace (v1.0+), `shell:*` fallback, GTK layer shell, and hyprlock
- *Cursor*: Bibata-Modern-Ice (white variant — high visibility on dark OLED backgrounds)

---

## Pre-Installation Requirements

- A USB drive (2 GB minimum) for the NixOS installer
- An internet connection (Ethernet recommended during install; Wi-Fi works but requires extra steps in the live environment)
- The NixOS minimal ISO image, downloadable from [nixos.org/download](https://nixos.org/download/#nixos-iso)

### Prepare the Installer

Download the **NixOS Minimal ISO** (not Graphical) and write it to a USB drive:

```bash
# From an existing Linux system (replace /dev/sdX with your USB device)
sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

On Windows, use [Rufus](https://rufus.ie/) or [balenaEtcher](https://etcher.balena.io/).

### BIOS Settings

Boot into BIOS (press `F2` during POST) and verify:

1. **Secure Boot** → Disabled (NixOS can work with Secure Boot, but it complicates the initial setup)
2. **Boot Mode** → UEFI only (not CSM/Legacy)
3. **Boot Priority** → USB first (or use `F8` boot menu to select the USB)

---

## Installation

### Step 1 — Boot the Live Environment

Boot from the USB drive. You will land at a root shell. If you need Wi-Fi:

```bash
# Interactive Wi-Fi connection
nmtui
# Or command-line:
nmcli device wifi connect "SSID" password "PASSWORD"
```

Verify connectivity:

```bash
ping -c 3 nixos.org
```

### Step 2 — Identify the Target Drive

```bash
lsblk
```

The Samsung 990 Pro will appear as `nvme0n1`. Confirm the drive size (≈931.5 GiB for 1 TB) and ensure you are targeting the correct device. The following steps will **destroy all data** on this drive.

### Step 3 — Partition the Drive

This configuration expects three partitions:

| Partition | Type | Size | Purpose |
|---|---|---|---|
| `nvme0n1p1` | EFI System (FAT32) | 1 GiB | Boot partition (`/boot`) |
| `nvme0n1p2` | Linux swap | 16 GiB | Swap (hibernate target) |
| `nvme0n1p3` | Linux filesystem (Btrfs) | Remainder | Root filesystem |

The EFI partition is generously sized at 1 GiB to accommodate multiple kernel generations and GRUB assets without running out of space. The swap partition is sized to match RAM (16 GiB) for reliable hibernate support.

```bash
# Wipe existing partition table and create a fresh GPT layout
gdisk /dev/nvme0n1
```

Inside `gdisk`:

```
Command: o          ← create new empty GPT partition table
Proceed? Y

Command: n          ← new partition (EFI)
Partition number: 1
First sector: (accept default)
Last sector: +1G
Hex code: EF00

Command: n          ← new partition (swap)
Partition number: 2
First sector: (accept default)
Last sector: +16G
Hex code: 8200

Command: n          ← new partition (Btrfs root)
Partition number: 3
First sector: (accept default)
Last sector: (accept default — uses remaining space)
Hex code: 8300

Command: w          ← write and exit
Proceed? Y
```

### Step 4 — Format the Partitions

```bash
# EFI partition
mkfs.fat -F 32 -n EFI /dev/nvme0n1p1

# Swap partition
mkswap -L SWAP /dev/nvme0n1p2

# Btrfs root partition
mkfs.btrfs -L NIXOS -f /dev/nvme0n1p3
```

### Step 5 — Create Btrfs Subvolumes

The subvolume layout isolates system, user data, Nix store, logs, and snapshots. This allows targeted snapshot/restore operations and prevents snapshot bloat from the Nix store.

```bash
# Temporarily mount the Btrfs partition to create subvolumes
mount /dev/nvme0n1p3 /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots

# Unmount the temporary mount
umount /mnt
```

**Subvolume purposes:**

| Subvolume | Mountpoint | Purpose |
|---|---|---|
| `@` | `/` | Root filesystem |
| `@home` | `/home` | User data — independently snapshotable |
| `@nix` | `/nix` | Nix store — excluded from snapshots (reproducible from flake) |
| `@log` | `/var/log` | Logs — preserved across root rollbacks |
| `@snapshots` | `/.snapshots` | Snapper snapshot storage |

### Step 6 — Mount Everything

The mount options enable transparent zstd compression (level 1 for speed), asynchronous TRIM for the NVMe, and disable access-time updates to reduce write amplification on the SSD.

```bash
# Common mount options
OPTS="compress=zstd:1,noatime,discard=async,space_cache=v2"

# Mount subvolumes
mount -o subvol=@,$OPTS         /dev/nvme0n1p3 /mnt
mkdir -p /mnt/{home,nix,var/log,.snapshots,boot}
mount -o subvol=@home,$OPTS     /dev/nvme0n1p3 /mnt/home
mount -o subvol=@nix,$OPTS      /dev/nvme0n1p3 /mnt/nix
mount -o subvol=@log,$OPTS      /dev/nvme0n1p3 /mnt/var/log
mount -o subvol=@snapshots,$OPTS /dev/nvme0n1p3 /mnt/.snapshots

# Mount EFI partition
mount /dev/nvme0n1p1 /mnt/boot

# Enable swap
swapon /dev/nvme0n1p2
```

Verify the layout:

```bash
findmnt --target /mnt --real
```

You should see all five Btrfs subvolumes and the EFI partition mounted under `/mnt`.

### Step 7 — Generate Hardware Configuration

```bash
nixos-generate-config --root /mnt
```

This creates two files in `/mnt/etc/nixos/`:

- `hardware-configuration.nix` — Machine-specific: filesystem mounts, kernel modules, detected hardware. **Keep this file and make sure it is git-tracked** — Nix flakes only evaluate files known to git.
- `configuration.nix` — A default starter config. **This will be replaced** by the files from this repository.

### Step 8 — Clone This Repository

With flakes, NixOS configurations can live anywhere — they don't need to be in `/etc/nixos`. This setup uses `~/nixos-config` as the primary location, keeping your config in your home directory where it's version-controlled and easy to manage.

```bash
# Install git in the live environment
nix-env -iA nixos.git

# Clone into the user's home directory
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git /mnt/home/asif/nixos-config

# Copy the auto-generated hardware config into the repo
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/asif/nixos-config/

# IMPORTANT: Stage the new file — Nix flakes only evaluate git-tracked files
cd /mnt/home/asif/nixos-config
git add hardware-configuration.nix
```

Alternatively, if you have the files on a USB drive or downloaded manually:

```bash
mkdir -p /mnt/home/asif/nixos-config
cp flake.nix configuration.nix hardware-tweaks.nix hyprland.nix home.nix /mnt/home/asif/nixos-config/
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/asif/nixos-config/

# Initialize git and stage all files — flakes require this
cd /mnt/home/asif/nixos-config
git init
git add .
```

**Verify the directory structure:**

```bash
ls -la /mnt/home/asif/nixos-config/
```

You should see:

```
flake.nix
configuration.nix
hardware-configuration.nix   ← auto-generated, unique to this machine
hardware-tweaks.nix
hyprland.nix
home.nix
```

### Step 9 — Review and Personalize

Before building, review and adjust the following:

**`configuration.nix`:**
- `time.timeZone` — Currently set to `"Asia/Dhaka"`. Change to your timezone. List available zones with `timedatectl list-timezones`.
- `i18n.defaultLocale` — Currently `"en_US.UTF-8"`. Change if needed.
- `users.users.asif` — Change username if desired. If you change it, also update `home-manager.users.asif` in `flake.nix` and the `home` block in `home.nix`.

**`home.nix`:**
- `programs.git.userName` and `programs.git.userEmail` — Set your actual Git identity.

**`hardware-configuration.nix`:**
- This file was auto-generated and should already reflect the partitions and subvolumes you created. Open it and verify the mount options include `compress=zstd:1`, `noatime`, and `discard=async`, and that the subvolume paths are correct. If `nixos-generate-config` did not detect them perfectly, adjust manually.

### Step 10 — Install

```bash
# Install the system (the flake name matches nixosConfigurations.zenbook)
nixos-install --flake /mnt/home/asif/nixos-config#zenbook
```

This will:
1. Download and build all packages from nixpkgs-unstable
2. Set up the bootloader (GRUB with EFI)
3. Create the user account
4. Deploy all Home Manager configurations

At the end you will be prompted to set the **root password**. Set a strong one.

The initial build may take 15–45 minutes depending on internet speed, as it downloads the entire package closure.

### Step 11 — Reboot

```bash
umount -R /mnt
reboot
```

Remove the USB drive when prompted or during POST.

---

## First Boot

### 1. Automatic Login

On first boot, greetd's `initial_session` will automatically log you in as `asif` and launch Hyprland — no password prompt. On subsequent boots or after logging out, tuigreet will appear and ask for your password.

### 2. Change Your Password

Open a terminal (`Super + Return`) and set a strong password immediately:

```bash
passwd
```

The `initialPassword` in the configuration (`changeme`) is only for emergency TTY access.

### 3. Install Ambxst

Ambxst is the desktop shell (bar, launcher, notifications, and more). It is installed via the Nix user profile, not the system configuration, because it is a third-party flake:

```bash
nix profile add github:Axenide/Ambxst
```

This pulls Ambxst and its dependencies (Quickshell, etc.) into your user profile.

### 4. Launch Hyprland

Hyprland starts automatically via greetd. If you need to restart the session manually (e.g., after installing Ambxst), log out with `Super + Shift + Escape` and log back in via tuigreet.

### 5. Connect to Wi-Fi (if not already connected)

Use the Ambxst Wi-Fi widget in the bar, or from a terminal:

```bash
nmtui
```

### 6. Verify Services

Open a terminal (`Super + Return`) and check that key services are running:

```bash
# Hyprland session
echo $XDG_CURRENT_DESKTOP     # should print: Hyprland

# Audio
wpctl status                   # PipeWire/WirePlumber status

# Bluetooth
bluetoothctl show              # adapter info

# Idle daemon
systemctl --user status hypridle

# Polkit agent
systemctl --user status polkit-gnome-authentication-agent-1

# Snapper timelines
sudo snapper -c root list
sudo snapper -c home list
```

---

## Post-Install Configuration

### Symlink /etc/nixos (Optional)

The configuration lives in `~/nixos-config`. If you want `nixos-rebuild` to also work without the `--flake` flag, or if any tool expects a config in `/etc/nixos`, create a symlink:

```bash
sudo rm -rf /etc/nixos
sudo ln -s /home/asif/nixos-config /etc/nixos
```

This is purely optional — the `rebuild` and `update` aliases already point to `~/nixos-config`.

### Push to GitHub

```bash
cd ~/nixos-config

git add .
git commit -m "NixOS Zenbook S 13 OLED configuration"
git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

> **Note:** `hardware-configuration.nix` is machine-specific (contains UUIDs, kernel modules, and filesystem entries unique to your hardware). It **must** be tracked by git because Nix flakes only evaluate git-tracked files. If you reinstall on different hardware, regenerate it with `nixos-generate-config` and commit the updated version.

### Hyprpaper (Wallpaper)

Create a hyprpaper configuration to set your wallpaper:

```bash
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprpaper.conf << 'EOF'
preload = ~/Pictures/Wallpapers/wallpaper.png
wallpaper = eDP-1, ~/Pictures/Wallpapers/wallpaper.png
splash = false
EOF
```

Add `hyprpaper` to `exec-once` in `home.nix` if you want it to start automatically (Ambxst may handle wallpaper separately via its own wallpaper selector — `Super + ,`).

### Hyprlock (Lock Screen)

Create a hyprlock configuration:

```bash
cat > ~/.config/hypr/hyprlock.conf << 'EOF'
background {
    monitor =
    path = ~/Pictures/Wallpapers/wallpaper.png
    blur_passes = 3
    blur_size = 8
}

input-field {
    monitor =
    size = 300, 50
    outline_thickness = 3
    dots_size = 0.25
    dots_spacing = 0.15
    fade_on_empty = true
    placeholder_text = <i>Password...</i>
    position = 0, -20
    halign = center
    valign = center
}
EOF
```

---

## Daily Usage

### Keybindings

#### Window Management

| Keybind | Action |
|---|---|
| `Super + C` | Close window |
| `Super + Space` | Toggle floating |
| `Super + F` | Fullscreen (covers bar) |
| `Super + Shift + F` | Maximize (keeps bar/gaps) |
| `Super + Ctrl + F` | Internal fullscreen |
| `Super + P` | Pseudo-tile |
| `Super + Shift + D` | Toggle dwindle split |
| `Super + Y` | Pin floating window |
| `Super + G` | Center floating window |
| `Super + Tab` | Switch to dwindle layout |
| `Super + Shift + Tab` | Switch to master layout |
| `Super + Shift + Escape` | Exit Hyprland |

#### Focus and Movement

| Keybind | Action |
|---|---|
| `Super + H/J/K/L` | Move focus (left/down/up/right) |
| `Super + Shift + H/J/K/L` | Move window |
| `Super + Ctrl + H/J/K/L` | Resize window (repeatable) |
| `Super + Alt + H/J/K/L` | Move floating window (repeatable) |
| Arrow key variants | Same as HJKL for all the above |
| `Super + Mouse drag (left)` | Move window |
| `Super + Mouse drag (right)` | Resize window |

#### Workspaces

| Keybind | Action |
|---|---|
| `Super + 1–9, 0` | Switch to workspace 1–10 |
| `Super + Shift + 1–9, 0` | Move window to workspace 1–10 |
| `Super + Z` | Previous workspace |
| `Super + X` | Next active workspace |
| `Super + Scroll` | Cycle workspaces |
| 3-finger horizontal swipe | Swipe between workspaces (gesture system, Hyprland ≥0.51) |

#### Applications

| Keybind | Action |
|---|---|
| `Super + Return` | Terminal (Ghostty) |
| `Super + Shift + Return` | Floating terminal |
| `Super + E` | File manager (Thunar) |
| `Super + Shift + E` | Floating file manager |
| `Super + W` | Firefox |
| `Super + Shift + W` | Firefox private window |

#### Ambxst Shell

| Keybind | Action |
|---|---|
| `Super + D` | Dashboard / app launcher |
| `Super + A` | AI assistant |
| `Super + ,` (comma) | Wallpaper selector |
| `Super + Shift + B` | Reload shell CSS |
| `Super + Alt + B` | Restart shell |
| `Super + Ctrl + B` | Toggle bar visibility |

#### Screenshots

| Keybind | Action |
|---|---|
| `Print` | Area screenshot → clipboard + file |
| `Shift + Print` | Full screen screenshot → clipboard + file |
| `Super + Shift + S` | Area screenshot → clipboard only |

Screenshots are saved to `~/Pictures/Screenshots/`.

#### Media and Hardware

| Keybind | Action |
|---|---|
| Volume keys | Raise/lower volume (5% steps) |
| Brightness keys | Raise/lower brightness (5% steps) |
| Mute key | Toggle mute |
| Mic mute key | Toggle microphone mute |
| Play/Pause/Next/Prev | Media player control |

#### System

| Keybind | Action |
|---|---|
| `Super + Ctrl + Escape` | Lock screen (hyprlock) |

### Idle Behavior (OLED Protection)

The idle chain is tuned for OLED burn-in prevention:

| Timeout | Action |
|---|---|
| 3 minutes | Dim screen to 10% |
| 5 minutes | Lock screen |
| 8 minutes | Turn display off (DPMS) |
| 15 minutes | Suspend |

Brightness is restored automatically on resume.

---

## System Maintenance

### Rebuild After Config Changes

```bash
# Build and switch (alias: rebuild)
sudo nixos-rebuild switch --flake ~/nixos-config#zenbook

# Test without making it the boot default (alias: rebuild-test)
sudo nixos-rebuild test --flake ~/nixos-config#zenbook
```

### Update All Packages

```bash
# Update flake inputs and rebuild (alias: update)
cd ~/nixos-config
sudo nix flake update
sudo nixos-rebuild switch --flake .#zenbook
```

### Garbage Collection

```bash
# Remove old generations and unused store paths (alias: gc)
sudo nix-collect-garbage -d

# List current generations before cleaning
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Automatic garbage collection is also configured: generations older than 14 days are cleaned weekly.

### Btrfs Snapshots (Snapper)

```bash
# List snapshots for root
sudo snapper -c root list

# List snapshots for home
sudo snapper -c home list

# Create a manual snapshot before a big change
sudo snapper -c root create --description "Before kernel update"

# Restore from a snapshot (advanced — boots into old snapshot)
# See: https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot
```

Snapper automatically creates and cleans timeline snapshots (hourly/daily/weekly/monthly) as configured.

### Btrfs Health Check

```bash
# Filesystem usage and compression ratio
sudo btrfs filesystem usage /
sudo compsize /

# Manual scrub (also runs weekly automatically)
sudo btrfs scrub start /
sudo btrfs scrub status /
```

### Rollback to Previous Generation

If a rebuild breaks something:

```bash
# Boot menu: GRUB shows previous generations — select one to roll back

# Or from the command line:
sudo nixos-rebuild switch --rollback
```

---

## Troubleshooting

### No Wi-Fi After Install

The MediaTek MT7922 requires non-free firmware. Verify that `hardware.enableAllFirmware = true` is in `hardware-tweaks.nix` and that `nixpkgs.config.allowUnfree = true` is in `configuration.nix`. Rebuild and reboot.

If Wi-Fi drops intermittently, try disabling ASPM for the Wi-Fi chip. Uncomment this line in `hardware-tweaks.nix`:

```nix
boot.kernelParams = lib.mkAfter [ "mt7921e.disable_aspm=Y" ];
```

### Screen Flickering or Artifacts

Ensure `amdgpu` is loaded early in initrd (it should be, via `boot.initrd.kernelModules = [ "amdgpu" ]` in `configuration.nix`). If you see cursor artifacts, `cursor.no_hardware_cursors = true` is already set in the Hyprland config.

### Hibernate Fails

Verify that `boot.resumeDevice` points to your swap partition and that the swap partition is at least as large as your RAM:

```bash
swapon --show         # should show /dev/nvme0n1p2, 16G
cat /proc/cmdline     # should contain resume=/dev/nvme0n1p2
```

### GTK Apps Show Light Theme

Dark mode is enforced through three mechanisms. If an app still shows a light theme:

1. Check the environment variable: `echo $GTK_THEME` (should be `Adwaita:dark`)
2. Check dconf: `dconf read /org/gnome/desktop/interface/color-scheme` (should be `'prefer-dark'`)
3. For Flatpak apps, you may need to override: `flatpak override --user --env=GTK_THEME=Adwaita:dark`

### Thunar Shows No Thumbnails

Verify `tumbler` is installed: `which tumblerd`. If missing, ensure `tumbler` is in `home.packages` and rebuild.

### Privilege Escalation Dialogs Don't Appear

This means the polkit agent is not running. Check its status:

```bash
systemctl --user status polkit-gnome-authentication-agent-1
```

If it failed to start, try restarting it manually:

```bash
systemctl --user restart polkit-gnome-authentication-agent-1
```

### NVMe Issues After Sleep

The Samsung 990 Pro has a known firmware issue with deep sleep states. The kernel parameter `nvme_core.default_ps_max_latency_us=5500` (set in `configuration.nix`) limits aggressive power saving. If you still experience issues, update the drive firmware via Samsung Magician (Windows) or `fwupd`:

```bash
fwupdmgr refresh
fwupdmgr get-updates
fwupdmgr update
```

### "Ambxst not found" After First Boot

Ambxst is installed to the user profile, not the system. Ensure you ran:

```bash
nix profile add github:Axenide/Ambxst
```

Then restart Hyprland or run `ambxst` from a terminal.

### greetd Shows a Blank Screen or Crashes

If greetd fails to start properly, switch to another TTY (`Ctrl + Alt + F2`) and check its logs:

```bash
journalctl -u greetd --no-pager -n 50
```

If the GPU is not ready when greetd launches (rare on AMD), you can add a delay:

```nix
# In configuration.nix, add to systemd.services.greetd:
systemd.services.greetd.serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
```

### Login Loop (greetd Keeps Restarting)

If Hyprland crashes on launch and greetd keeps respawning the greeter, switch to TTY2 (`Ctrl + Alt + F2`), log in, and check the Hyprland log:

```bash
cat /tmp/hypr/$(ls -t /tmp/hypr/ | head -1)/hyprland.log
```

---

## File Reference

### flake.nix

The flake entry point. Pins `nixpkgs` to the unstable channel and integrates Home Manager as a NixOS module. The single output, `nixosConfigurations.zenbook`, ties all modules together.

### configuration.nix

System-level configuration covering boot (GRUB with EFI, latest kernel, hibernate support), display manager (greetd with tuigreet), networking (NetworkManager with firewall), locale and time, PipeWire audio, Bluetooth, zram swap, Btrfs auto-scrub, Snapper snapshots, fonts (Noto, Inter, Nerd Fonts), and essential services (dbus, polkit, fwupd, upower, udisks2, gvfs, fstrim).

### hardware-configuration.nix

Auto-generated by `nixos-generate-config`. Contains detected kernel modules, filesystem mount entries with UUIDs, and hardware-specific settings. This file **must** be git-tracked because Nix flakes only evaluate tracked files. Regenerate with `nixos-generate-config` when reinstalling on different hardware.

### hardware-tweaks.nix

Zenbook-specific hardware tuning: AMD GPU with RADV Vulkan driver (enabled by default), CPU microcode updates, firmware blobs, Samsung 990 Pro NVMe workarounds, IIO sensors for the accelerometer and ambient light sensor, TLP power management with dynamic governor switching, logind lid/suspend behavior, and power-profiles-daemon conflict prevention.

### hyprland.nix

System-level Hyprland setup: enables Hyprland and XWayland, configures XDG desktop portals (hyprland + GTK), enables dconf for theme propagation, and sets Wayland session variables (Ozone, Mozilla, Qt, SDL, Clutter).

### home.nix

User configuration managed by Home Manager. Contains all user packages (CLI tools, media, Wayland utilities, Hyprland ecosystem, development tools, theming), the complete Hyprland window manager configuration (monitor scaling, input, gestures, decorations, animations, layouts, window rules, keybindings), hypridle service (OLED-optimized idle chain), cursor and GTK/Qt/dconf theming, XDG directories, Ghostty terminal configuration, Git settings, Bash aliases, Firefox with hardware acceleration, polkit-gnome systemd service, fzf, and direnv.

---

## License

This configuration is provided as-is for personal use. Adapt freely.
