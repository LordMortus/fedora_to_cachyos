# Fedora 44 Gaming VM — CachyOS + Sunshine on Proxmox

A fully automated pipeline to set up a Fedora 44 gaming VM on Proxmox with GPU
passthrough, CachyOS kernel, and Sunshine game streaming. Built and debugged with
Claude AI over many sessions.

> **Use these scripts at your own risk.**
> Tested on real hardware — your mileage may vary.
> Always read a script before running it.

---

## What This Sets Up

- Fedora 44 minimal install (headless, no desktop by default)
- CachyOS kernel (automatically selects LTS for older CPUs)
- NVIDIA GPU passthrough drivers
- Sunshine game streaming host (paired with Moonlight on your client)
- Steam, Proton-GE, Heroic Games Launcher, MangoHud, Gamemode

---

## Before You Start

- Machine type: q35, BIOS: OVMF (UEFI)
- EFI disk — NO pre-enrolled keys (disables Secure Boot)
- GPU passthrough device added but set as **secondary** initially
  (primary GPU stays virtual so you can use the Proxmox console)
- Dummy HDMI dongle on GPU required (needed once set to primary)
- VirtIO network adapter
- VirtIO RNG device (required for entropy during UEFI PXE boot)
- Boot order: Network first, then disk
- The scripts detect your CPU architecture automatically and install the
  appropriate CachyOS kernel variant (standard for x86-64-v3, LTS for x86-64-v2)

> **After the kickstart completes and the VM shuts down:**
> Switch the GPU to primary in Proxmox before starting the VM again.
> The Proxmox console will go dark from this point on — SSH is your only way in.
> The automated setup will continue on its own after the cold start.

---

## Compositor Paths

### Niri (Wayland) — ✅ Tested and confirmed working
Lightweight Wayland compositor, no full desktop environment.
Minimal RAM usage, ideal for a dedicated streaming VM.
Use `script-master-niri.sh` — fully automated end to end via PXE.

### KDE Plasma (Wayland) — ⚠️ Expected to work, not fully tested
Full desktop experience. Requires adding `@kde-desktop-environment`
to the kickstart `%packages` section before deploying.
Use `script-master-kde.sh`.
Not end-to-end tested in the automated pipeline — the individual
stage scripts are largely the same as the Niri path with compositor
specific differences in stage 3 and no Niri stage.

---

## Automated Setup (Recommended)

The fully automated path uses PXE boot (assumes you have a netboot.xyz
server) and a kickstart file to go from empty disk to fully configured 
streaming VM with minimal interaction.

1. Set up PXE infrastructure (see `ixpe/` folder and `notes/`)
2. Deploy `ixpe/fedora-gaming.ks` to your HTTP server
   - Fill in your password hash, Proxmox API token, VM ID
   - Generate password hash: `openssl passwd -6`
3. Boot VM from network
4. Select the fedora os from local installs - wait for VM to shutdown
5. Change your VM hardware settings to use the gpu passthrough as primary
    display, start VM (as stated in Before you start notes).
6. Walk away — come back in ~1 hour
8. SSH in and confirm Sunshine is running:
   ```
   systemctl --user status app-dev.lizardbyte.app.Sunshine
   ```
9. On your system that you plan to install monlight on, enable an
   SSH tunnel in a command prompt: SSH -L 47990:<localhost>:47990 <user@vm-ip>
10. Open a web browser to localhost:47990 and setup Sunshine
11. Pair/Connect with Moonlight

---

## Manual Setup

Run these in order. Each script tells you when a reboot is required.

| Script | What it does | Reboot after? |
|---|---|---|
| `bootstrap.sh` | Creates your user, sets hostname, starts script chain | No |
| `scripts/script1-base.sh` | System update, RPM Fusion, CachyOS kernel | **Yes** |
| `scripts/script2-nvidia.sh` | NVIDIA driver install | **Yes** |
| `scripts/script3-sunshine.sh` | Sunshine streaming host, firewall, compositor config | **Yes** |
| `scripts/script4-falcond.sh` | falcond performance daemon (built from source) | No |
| `scripts/script5-gaming.sh` | Steam, ProtonUp-Qt, Heroic, MangoHud, Gamemode | No |

---

## Tips

- Sunshine starts automatically as a user service — no autostart config needed
- Add Steam to autostart manually if you want it on boot
- Run ProtonUp-Qt with Steam closed to install Proton-GE
- Recommended Steam launch options: `MANGOHUD=1 gamemoderun %command%`
- Sunshine web UI: `https://<vm-ip>:47990` (view only)
- To save config changes use an SSH tunnel:
  ```
  ssh -L 47990:localhost:47990 <user>@<vm-ip>
  ```
  Then open `https://localhost:47990` in your browser

---

## Monitoring Setup Progress

```bash
./watch.sh
```

Gives you a menu to follow the first boot service or resume service logs
during automated setup. Run it after SSH-ing in during a fresh deployment
to watch the stages tick over in real time.

---

## Known Issues

- **ProtonUp-Qt** — current Flathub build has a Qt version mismatch and won't launch.
  Upstream issue, not related to this setup. Check for Flathub updates or install
  Proton-GE manually into `~/.steam/root/compatibilitytools.d/`

---

## Optional Storage Scripts

| Script | What it does |
|---|---|
| `extras/script6-shares.sh` | Mount NFS and/or Samba network shares permanently |
| `extras/script7-iscsi.sh` | Connect a single iSCSI target (formats new disk) |
| `extras/script8-iscsi-existing.sh` | Connect a single iSCSI target (preserves existing data) |
| `extras/script9-iscsi-multi.sh` | Connect multiple iSCSI targets |

---

## Notes and Debug Path

See the `notes/` folder for:
- Full debug history of everything that went wrong and how it was fixed
- SSH setup guide for Windows
- PXE infrastructure details
