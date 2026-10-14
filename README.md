# vlc-redesign-nix

A Nix flake that builds [dsojevic's VLC redesign](https://github.com/dsojevic/vlc) on NixOS. The fork is a VLC 4.0 development tree with a new Qt interface adapted from [Juxtopposed's Figma design](https://www.figma.com/community/file/1691465999134370980/vlc-redesign). Upstream only ships Windows betas, so this repo is the missing Linux build recipe.

This repo contains packaging only. I didn't write the player, the redesign or the design. I'm not affiliated with VideoLAN, dsojevic or Juxtopposed.

It's a development build of VLC 4, so expect rough edges. It replaces your VLC 3 rather than extending it, and the fork changes daily.

## Try it without installing

```
nix run github:iankengott/vlc-redesign-nix
```

The first run builds VLC from source. There's no binary cache, so it compiles about 2,300 files. On a 16-thread laptop that took roughly 15 to 20 minutes. Use `--cores` if you want to leave some CPU free.

## Install it on NixOS

Add the flake as an input and put the package in your system packages.

```nix
# flake.nix
inputs.vlc-redesign.url = "github:iankengott/vlc-redesign-nix";

# configuration.nix
environment.systemPackages = [
  inputs.vlc-redesign.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

This package provides a `vlc` binary, so remove `vlc` from the same package list or the two will collide. If you'd rather keep VLC 3 around, install this one from a separate profile and launch it by store path.

If you don't use flakes, copy `package.nix` into your config and call it with `pkgs.callPackage ./package.nix { }`.

The flake's `overlays.default` is there too, but I'd avoid it unless you need it. The package output uses the nixpkgs revision pinned in `flake.lock`, which is the one I tested. The overlay uses yours, and a renamed library in a newer or older nixpkgs will break the build.

## What you may need to change

Things I checked on one machine and can't promise elsewhere.

- **Architecture.** I tested x86_64-linux only. The flake lists only that system. aarch64 might work, but I haven't tried it.
- **Desktop.** Tested on KDE Plasma under Wayland with an AMD GPU. The Qt Wayland and X11 plugins both build.
- **nixpkgs version.** The pin is nixos-unstable from October 2026. On a stable channel, some attribute names in `package.nix` (for example `libxcb-keysyms`, `libx11`, `libxext`) may be spelled differently. The build error will name the missing one.
- **Existing VLC settings.** VLC 4 reads the same `~/.config/vlc` as VLC 3 and rewrites parts of it. Back it up first if you want to go back.
- **First launch is slow.** The meson build doesn't produce VLC's plugin cache, so VLC scans every plugin on each start. The window shows up, but give it a few seconds.
- **Hardware.** VLC 4 uses Qt 6 and Mesa OpenGL. Nothing in the package pins a GPU, but I haven't tried NVIDIA.

## Choices the package makes

- **Rust modules are off.** They're experimental and need a nightly toolchain, so I left them out.
- **Chromecast is off.** The plugin needs C++20 for its protobuf and abseil headers, and VLC builds as C++17. Casting won't work.
- **`mesonAutoFeatures = "auto"`.** nixpkgs defaults meson to requiring every optional feature, which fails on options like AArch64 branch protection.
- **A RUNPATH patch for the X11 video plugins.** Without it they can't find `libvlc_xcb_events.so` and fail to load.
- **A desktop entry and icons.** The meson install doesn't ship them. They're generated from the fork's own files in a separate derivation, so editing them doesn't trigger a recompile. The entry drops `--started-from-file`, which VLC 4 removed and which otherwise makes the launcher entry exit without opening anything.

## Updating

The fork moves quickly, so the package is pinned to one commit. To move it forward, get the new commit and its hash.

```
git ls-remote https://github.com/dsojevic/vlc HEAD
nix flake prefetch github:dsojevic/vlc/<commit>
```

Put the commit in `rev` and the `hash` value in `package.nix`, and update `version` to match. The build can break when upstream adds dependencies, so check that `nix build` still succeeds and the window opens before you rely on it.

## Known problems

- At one point the app showed "unable to open the MRL file:///home/<user>/player" errors. I haven't found what triggers it, and I haven't confirmed whether it's in the fork or in my build.
- It's a development snapshot. Crashes and missing features are the fork's, not Nix's.

## Credits and licenses

- VLC is from [VideoLAN](https://www.videolan.org/) under GPLv2 or later. The VLC name and cone logo are their trademarks, so don't redistribute builds as "VLC" without checking their guidelines.
- The redesigned interface is [dsojevic's fork](https://github.com/dsojevic/vlc), which follows the design by [Juxtopposed](https://www.juxtopposed.com/), licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- `package.nix` started from the VLC derivation in [nixpkgs](https://github.com/NixOS/nixpkgs), which is MIT.
- The Nix packaging in this repo is MIT. See `LICENSE`.
