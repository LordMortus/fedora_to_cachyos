# Fedora 44 Gaming VM — CachyOS + Sunshine on Proxmox

> **⚠️ USE THESE SCRIPTS AT YOUR OWN RISK**
> This is a work in progress. Things may break. As issues are found they will be fixed.
> Always read a script before running it so you know what it does to your system.

A script collection to set up a Fedora 44 gaming VM on Proxmox with GPU passthrough,
the CachyOS kernel, and Sunshine game streaming. Built and tested on real hardware
with help from Claude AI to debug and refine along the way.

---

## What This Sets Up

- Fedora 44 minimal install (no desktop — you choose one below)
- CachyOS kernel (automatically selects LTS for older CPUs)
- NVIDIA GPU passthrough drivers
- Sunshine game streaming host (paired with Moonlight on your client)
- Steam, Proton-GE, Heroic Games Launcher, MangoHud, Gamemode

---

## Before You Start

- The PCI GPU needs to be visible to the VM to install the correct NVIDIA drivers.
  It does **not** need to be set as the primary display until you are ready to stream.
- Make sure the EFI disk in Proxmox does **NOT** have pre-generated keys.
- All setup is done over SSH — the VM is headless throughout.
- The scripts detect your CPU architecture automatically and install the appropriate
  CachyOS kernel variant (standard for x86-64-v3, LTS for x86-64-v2).

---

## Compositor Paths

The scripts are compositor-aware and detect your environment automatically.
Two paths are confirmed working in the real world:

### KDE Plasma (Wayland)
The typical choice if you want a full desktop experience on the VM.
KDE is installed separately before running the script chain — the scripts
detect it and apply the appropriate power management and KWin settings automatically.

### Niri (Wayland)
A lightweight Wayland compositor with no full desktop environment.
Good if you want to minimise RAM usage and only need the VM for streaming.
Run `script-niri.sh` after completing the main script chain.
See the **Niri Path** section below.

---

## Main Script Chain

Run these in order. Each script tells you when a reboot is required.

| Script | What it does | Reboot after? |
|---|---|---|
| `install.ks` | Kickstart — minimal Fedora 44 install | Yes (VM powers off) |
| `bootstrap.sh` | Creates your user, sets hostname, starts script1 | No |
| `script1-base.sh` | System update, RPM Fusion, CachyOS kernel | **Yes** |
| `script2-nvidia.sh` | NVIDIA driver install | **Yes** |
| `script3-sunshine.sh` | Sunshine streaming host, firewall, compositor config | **Yes** |
| `script4-falcond.sh` | falcond performance daemon (built from source) | No |
| `script5-gaming.sh` | Steam, ProtonUp-Qt, Heroic, MangoHud, Gamemode | No |

### Master Script
`setup-master.sh` combines scripts 1–5 with systemd-based reboot persistence
so the chain resumes automatically after each reboot. It works but is less
tested than running the scripts individually — use it if you're comfortable
recovering from issues, otherwise run scripts one at a time.

---

## Niri Path

After completing scripts 1–5, run `script-niri.sh` to replace the desktop
environment with Niri:

- Installs PipeWire, SDDM, Niri, and supporting tools
- Configures SDDM autologin into a Niri session
- Wires Sunshine into the Niri session via systemd
- Sets graphical boot target so SDDM starts on boot

After rebooting into Niri, open the Sunshine web UI and set the capture
method to **portal** under Configuration → Video.

---

## Tips

- Sunshine is installed as a user service and starts automatically — you do
  not need to add it to any autostart list.
- You **will** need to add Steam to autostart manually if you want it to
  launch on boot.
- Run ProtonUp-Qt with Steam closed to install Proton-GE.
- Recommended Steam launch options: `MANGOHUD=1 gamemoderun %command%`
- If Moonlight gives a 503 error, use `restart-sunshine.bat` from your
  Windows machine (see `SSH-Setup-and-503-Fix.txt` for setup instructions).
  Power management is disabled automatically by script3, so this should
  rarely be needed.

### Sunshine Web UI
The web UI is accessible at `https://<vm-ip>:47990` from any browser on
your local network — no tunnel needed to view it. However, Sunshine's CSRF
protection blocks configuration saves from any origin other than localhost,
so to make and save changes you need an SSH tunnel:

```
ssh -L 47990:localhost:47990 <user>@<vm-ip>
```

Then open `https://localhost:47990` in your browser. Ignore the self-signed
SSL warning — this is expected. Sunshine automatically selects the best
capture method for your GPU; there is no capture method setting to configure.

---

## Storage Scripts (Optional)

These are standalone and can be run any time after the main chain:

| Script | What it does |
|---|---|
| `script6-shares.sh` | Mount NFS and/or Samba network shares permanently |
| `script7-iscsi.sh` | Connect a single iSCSI target (formats new disk) |
| `script8-iscsi-existing.sh` | Connect a single iSCSI target (preserves existing data) |
| `script9-iscsi-multi.sh` | Connect multiple iSCSI targets |
