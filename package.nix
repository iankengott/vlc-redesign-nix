# VLC 4.0 development tree with the Juxtopposed interface redesign.
# Source: https://github.com/dsojevic/vlc (GPLv2+ code, CC BY 4.0 design)
# Pinned to one commit because the fork changes daily. To update, bump `rev`
# and `hash` together (see README, "Updating").
{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  python3,
  flex,
  bison,
  gettext,
  lua5_2_compat,
  unzip,
  wayland-scanner,
  qt6,
  kdePackages,
  wrapGAppsHook3,
  removeReferencesTo,
  patchelf,
  symlinkJoin,
  runCommand,
  makeWrapper,
  alsa-lib,
  avahi,
  cairo,
  dbus,
  faad2,
  ffmpeg_7,
  flac,
  fontconfig,
  freefont_ttf,
  freetype,
  fribidi,
  gnutls,
  harfbuzz,
  libGL,
  libarchive,
  libass,
  libbluray,
  libcddb,
  libdvbpsi,
  libdvdnav,
  libebml,
  libgcrypt,
  libgpg-error,
  libjpeg,
  libmatroska,
  libogg,
  libopus,
  libplacebo,
  libpng,
  libpulseaudio,
  librsvg,
  libsamplerate,
  libssh2,
  libtheora,
  libva,
  libvorbis,
  libxml2,
  libxcb,
  libxcb-keysyms,
  libxkbcommon,
  libx11,
  libxext,
  libxinerama,
  libxpm,
  libsm,
  live555,
  ncurses,
  samba,
  speex,
  srt,
  systemdLibs,
  taglib,
  wayland,
  wayland-protocols,
  zlib,
}:

let
  vlc = stdenv.mkDerivation (finalAttrs: {
  pname = "vlc-redesign";
  version = "4.0.0-dev-b13cefb7";

  src = fetchFromGitHub {
    owner = "dsojevic";
    repo = "vlc";
    rev = "b13cefb7bbbd1b1673166e5e807c9bef953b43a4";
    hash = "sha256-jUizR2TL+DojSvDb1tF3BZqZWLydqYdvG2AIZdlzTqk=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    python3
    flex
    bison
    gettext
    lua5_2_compat
    unzip
    wayland-scanner
    qt6.wrapQtAppsHook
    qt6.qttools
    wrapGAppsHook3
    removeReferencesTo
    patchelf
  ];

  buildInputs = [
    alsa-lib
    avahi
    cairo
    dbus
    faad2
    ffmpeg_7
    flac
    fontconfig
    freetype
    fribidi
    gnutls
    harfbuzz
    libGL
    libarchive
    libass
    libbluray
    libcddb
    libdvbpsi
    libdvdnav
    libdvdnav.libdvdread
    libebml
    libgcrypt
    libgpg-error
    libjpeg
    libmatroska
    libogg
    libopus
    libplacebo
    libpng
    libpulseaudio
    librsvg
    libsamplerate
    libssh2
    libtheora
    libva
    libvorbis
    libxml2
    libxcb
    libxcb-keysyms
    libxkbcommon
    libx11
    libxext
    libxinerama
    libxpm
    libsm
    live555
    lua5_2_compat
    ncurses
    samba
    speex
    srt
    systemdLibs
    taglib
    wayland
    wayland-protocols
    zlib
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtsvg
    qt6.qtwayland
    qt6.qt5compat
    qt6.qtshadertools
    kdePackages.kwindowsystem
  ];

  strictDeps = true;
  dontWrapGApps = true; # Qt wrapper adds the gapps args below

  postPatch = ''
    patchShebangs buildsystem
    substituteInPlace modules/text_renderer/freetype/platform_fonts.h \
      --replace-fail \
        /usr/share/fonts/truetype/freefont \
        ${freefont_ttf}/share/fonts/truetype
  '';

  # nixpkgs defaults to auto_features=enabled, which makes optional probes
  # (AArch64 branch protection, every optional codec) hard errors.
  mesonAutoFeatures = "auto";

  mesonFlags = [
    "-Drust=disabled"
    "-Dchromecast=disabled" # protobuf/abseil headers need C++20; VLC builds as C++17
  ];

  # The xcb plugins link libvlc_xcb_events.so from $out/lib/vlc, which is not
  # in their RUNPATH, so they fail to load without this.
  postFixup = ''
    for f in $out/lib/vlc/plugins/video_output/libxcb_*_plugin.so; do
      patchelf --add-rpath $out/lib/vlc "$f"
    done
  '';

  preFixup = ''
    qtWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  meta = {
    description = "VLC 4.0 development build with the Juxtopposed interface redesign";
    homepage = "https://github.com/dsojevic/vlc";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "vlc";
  };
});

  # VLC 4 no longer loads the D-Bus control interface by default, so without
  # this there is no MPRIS service: KDE's media keys (and playerctl, KDE
  # Connect, etc.) have nothing to talk to. Wrapping outside the compiled
  # derivation keeps this a no-recompile change.
  wrapped = runCommand "vlc-redesign-wrapped" { nativeBuildInputs = [ makeWrapper ]; } ''
    makeWrapper ${vlc}/bin/vlc $out/bin/vlc --add-flags "--control=dbus"
  '';

  # The meson install ships no desktop entry or icons (the autotools build did),
  # so the app has no launcher/dock icon. Kept outside the compiled derivation so
  # tweaking it never triggers a recompile.
  desktop = runCommand "vlc-redesign-desktop" { } ''
    mimetypes="$(sed 's/\s*#.*$//g' ${vlc.src}/share/vlc.desktop.mimetypes | grep -v '^$' | tr '\n' ';')"
    mkdir -p $out/share/applications
    # VLC 4 dropped --started-from-file; passing it makes vlc exit with "Unknown option".
    sed -e "s,@bindir@,${wrapped}/bin,g" -e "s,@MIMETYPES@,$mimetypes,g" \
      -e 's, --started-from-file,,' \
      ${vlc.src}/share/vlc.desktop.in > $out/share/applications/vlc.desktop
    for sz in 16x16 32x32 48x48 128x128 256x256; do
      if [ -f ${vlc.src}/share/icons/$sz/vlc.png ]; then
        install -Dm444 ${vlc.src}/share/icons/$sz/vlc.png \
          $out/share/icons/hicolor/$sz/apps/vlc.png
      fi
    done
  '';
in
symlinkJoin {
  inherit (vlc) pname version meta;
  name = "${vlc.pname}-${vlc.version}";
  paths = [ wrapped vlc desktop ];
}
