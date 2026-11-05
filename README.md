# ohmarchy: Omarchy on HarmonyOS

Running [Omarchy](https://omarchy.org) (Arch Linux + Hyprland) on a HarmonyOS PC,
driven from a Linux host over `hdc`. Developed on a HUAWEI MateBook Fold
(HarmonyOS 7.0) with the AArch64 Omarchy build from
[riverscn/omarchy-aarch64-image](https://github.com/riverscn/omarchy-aarch64-image).

| Route | What runs on the HarmonyOS machine | Status |
|---|---|---|
| **A. Linux engine apps**: [docs/linux-engine-apps.md](docs/linux-engine-apps.md) | Omarchy's neovim setup and CLI tools inside HarmonyOS's Linux engine, each in a native HarmonyOS window | Works |
| **B. Whole OS in the Oseasy VM**: [docs/oseasy-whole-os.md](docs/oseasy-whole-os.md) | The complete Omarchy AArch64 OS in the Oseasy VM app, on a patched 7.2 kernel | The Hyprland desktop works (800x600, software rendering), with the VM's keyboard, touchpad and touch screen adapted; see status |

What was tried and why other paths fail: [docs/findings.md](docs/findings.md).

## Route B quick start

On a Linux host (`hdc` from the OpenHarmony SDK, USB debugging enabled on the
HarmonyOS machine):

```sh
oseasy/10-fetch-inputs.sh       # Omarchy image (3.7 GB), Debian 6.1 kernel debs, Debian netinst ISO
oseasy/20-build-modules.sh      # SVGA driver + efidrm module against Debian's 6.1 headers
oseasy/25-build-kernel-7.2.sh   # patched 7.2 kernel in a container (needed for the desktop)
oseasy/30-prepare-image.sh      # qcow2 -> raw, read the partition layout and root UUID
oseasy/26-package-kernel-7.2.sh # the 7.2 kernel as the linux-ohmarchy-oseasy package (root, in the image's root)
oseasy/27-build-aquamarine.sh   # aquamarine without the per-frame renderer retry (root, in the image's root)
oseasy/28-build-extras.sh       # ohmarchy-glfinish.so and the Pinyin packages (root, in the image's root)
oseasy/40-build-boot.sh         # boot entries (UKIs), Limine menu and first-boot files into the image's ESP
oseasy/50-make-installer-iso.sh # Debian netinst ISO carrying the Omarchy disk image
oseasy/60-push-iso.sh           # copy the ISO to the HarmonyOS Download folder
```

On macOS (or without the host tools), run the steps in a container with
`oseasy/in-docker.sh STEP...`, for example
`oseasy/in-docker.sh 26-package-kernel-7.2 27-build-aquamarine 28-build-extras 40-build-boot 50-make-installer-iso`;
25 and 60 still run on the host.

Then follow the install steps in [docs/oseasy-whole-os.md](docs/oseasy-whole-os.md#install-in-oseasy).
Settings live in `oseasy/config.sh`; outputs go to `work/`.

The guest's network shell (root on tcp/5000, without a password), which the
`tools/fold` helpers drive the VM through, is off unless the ISO is built with
`OHMARCHY_NETSHELL=1` in the environment of 40-build-boot.sh. Build that way
for development, never for an ISO others install.

GitHub Actions builds the ISO without the shell (`.github/workflows/oseasy-iso.yml`,
run by hand or by an `oseasy-v*` tag) and attaches it, split in parts, to a
draft pre-release.

Host tools: bash, python3, curl, unzip, bsdtar (libarchive), cpio, gzip,
qemu-img, sfdisk/blkid (util-linux), mtools, xorriso, kmod (depmod), make,
clang and the llvm tools (with the `aarch64` target, any recent version), hdc; docker or podman
for the 7.2 kernel. 26, 27 and 28 need root with btrfs and overlayfs on an aarch64
host (`docker run --privileged` on an Apple silicon Mac works).

## What Oseasy would need to change

These gaps in route B are on Oseasy's side, not Omarchy's or the kernel's.

**The install never completes, so the VM does not persist.** An Omarchy VM
lasts exactly as long as one run of it.

What happens:

- The VM boots and Omarchy runs normally, but Oseasy's main window keeps
  waiting for Windows and later reports 安装过程出现异常. Pressing 确定 leaves the
  VM running.
- Oseasy never lists the VM as installed and offers no entry to start it again.
- Ending the run ends the install. A shutdown from inside Omarchy ended at
  安装失败 with no way back to the disk, and so does closing the VM window
  (创建尚未完成，确定退出). The only way on is **再次安装**, which recreates the
  disk and boots the ISO again: everything in the VM is gone.
- Rebooting from inside Omarchy is fine: the VM restarts in place and boots
  its disk. Quitting Oseasy, restarting the HarmonyOS PC or updating HarmonyOS
  were not tried; with no start entry there is nothing to come back to.

Why:

- Creating a VM in Oseasy is a Windows install. The VM starts in an
  "installing" state, and it leaves that state only when Oseasy's own Windows
  guest tools, running inside the VM, report that Windows has booted. On the
  HarmonyOS side the VM manager then stops the VM to finish the install;
  recording it as installed and giving it a start entry happens in the Oseasy
  app, which we could not examine.
- There is no system type other than Windows, no way to mark an install as
  done by hand, no Linux version of the guest tools, and no documentation of
  what they send. So for Oseasy the Omarchy VM is a Windows install that never
  finished, and an unfinished install has nothing to resume: any end of the run
  counts as a failed install, and the retry starts from an empty disk.
- Imitating the Windows tools from Linux was not taken further. Nothing shows
  that Oseasy would then keep the disk, the protocol is undocumented, and every
  attempt puts the only running instance at risk.

What Oseasy could do (any one of the first three fixes it):

- a system type for Linux and other guests, or a button to confirm the install
  once the guest is up;
- creating a VM from an existing disk image, or importing one, as an installed
  instance;
- Linux guest tools, or a documented guest protocol, that report the install
  state the way the Windows tools do;
- and, independently, keep the disk when an install fails or is cancelled, and
  ask before 再次安装 recreates it.

Until then, if you use Omarchy in Oseasy:

- Minimize the VM window, never close it, and do not shut Omarchy down; reboot
  instead when you need to.
- Treat the VM as disposable. Keep your work and dotfiles outside it (a git
  remote, a sync service) so a reinstall, about twenty minutes from the ISO,
  costs nothing but the time.
- Copy anything you need out over the network before you stop the VM on
  purpose. In a development build, `tools/fold/guest-get.sh` copies files from
  the guest to the host over the network shell.

**The window stops refreshing in SVGA mode.** The VM's display device is a
VMware SVGA II with 3D, and with `driver/vmwgfx-oseasy` the guest could follow
the window size. But as soon as the guest driver enables SVGA mode, Oseasy
stops updating the window, so Omarchy stays on the firmware framebuffer at
800x600 with software rendering. Details in [docs/findings.md](docs/findings.md#the-oseasy-vm).

**No clipboard or shared folder with HarmonyOS.** Both come with Oseasy's
Windows guest tools, and a Linux guest gets neither:

- Every VM has a virtiofs device (tag `shared_dir`), but Oseasy starts
  `virtiofsd` without a directory to share unless its Windows tools set one up,
  so there is nothing for Linux to mount.
- Copy and paste between HarmonyOS and the VM is a feature of Oseasy's Windows
  guest agent, which talks to the host over the VM's virtio-serial ports; there
  is no Linux agent and no documented protocol to write one against.

Today files reach the VM only through the installer ISO or the network, and
text not at all. What would fix it: share the chosen HarmonyOS folder over
virtiofs for any guest (Linux mounts it with `mount -t virtiofs shared_dir
/mnt`), and offer the clipboard through a Linux agent or a documented channel
(the spice-vdagent protocol, for one, which Linux desktops already speak).

## Layout

```
oseasy/            build pipeline for route B (10..60), config, boot menu template
  initramfs/       overlay added to the 6.1 initramfs: bridge address and network shell, GPU modes, first-boot module install
  installer/       scripts run in the Debian installer's rescue shell inside the VM
  lib/             uki.py (assemble UKIs), modsubset.py (module + dependency subset), image-chroot.sh
  root/            first-boot setup for the installed system, and the VM's input services
  aquamarine/      aquamarine patch and its build in the image's root
  extras/          glfinish.c and the Pinyin packages' fetch, built in the image's root
  hyprland/        Hyprland patch for upstream (software rendering on firmware framebuffers)
kernel/            patched 7.2 kernel: ID registers added after v6.1 read as zero, config fragment
driver/
  vmwgfx-oseasy/   vmwgfx for the HarmonyOS SVGA device (indexed MMIO, display-unit selection)
  efidrm/          omarchy_efidrm: simpledrm on the EFI framebuffer for the Debian 6.1 kernel
tools/fold/        hdc helpers: screenshots, taps, keys, typing into the VM, guest shell, file copy
tools/kbuild/      build out-of-tree arm64 modules against Debian headers with clang
linux-engine/      route A install scripts (run inside the Linux engine container)
docs/
```

## License

`driver/` and `kernel/` are derived from the Linux kernel and are GPL-2.0. Upstream projects
used by the scripts keep their own licenses.
