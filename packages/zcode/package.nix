{
  lib,
  flake,
  platformSource,
  mkUpdater,
  stdenvNoCC,
  bintools,
  formatelf,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,

  # Directly linked (DT_NEEDED); auto-formatelf resolves these from
  # buildInputs and fails the build if any are missing.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gcc-unwrapped,
  glib,
  gtk3,
  libdrm,
  libX11,
  libxcb,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxkbcommon,
  libgbm,
  nspr,
  nss,
  pango,

  # Provides libudev, which the main binary links directly. The libs-only
  # build avoids pulling the whole systemd closure.
  systemdLibs,

  # Loaded at runtime via dlopen. Nothing lists these in DT_NEEDED, so they go
  # in runtimeDependencies to land on the RUNPATH regardless.
  libglvnd,
  libsecret,
  libnotify,
  libpulseaudio,
  libayatana-appindicator,
  libXcursor,
  pipewire,
  wayland,
  xdg-utils,

  # Needed for XDG_ICON_DIRS and GSETTINGS_SCHEMAS_PATH.
  adwaita-icon-theme,
  gsettings-desktop-schemas,
}:

let
  pname = "zcode";

  # Official Linux builds are electron-builder `.deb` packages; the download
  # server publishes one per platform under a per-release directory.
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
    };
    urlTemplate = "https://cdn-zcode.z.ai/zcode/electron/releases/{version}/{platform}/ZCode-{version}-{platform}.deb";
  };

  desktopItem = makeDesktopItem {
    name = "zcode";
    desktopName = "ZCode";
    genericName = "Agentic Development Environment";
    comment = "ZCode Desktop App";
    exec = "zcode %U";
    icon = "zcode";
    categories = [ "Development" ];
    startupWMClass = "ZCode";
    mimeTypes = [ "x-scheme-handler/zcode" ];
  };
in
stdenvNoCC.mkDerivation {
  inherit pname;
  inherit (source) version src;

  nativeBuildInputs = [
    formatelf
    copyDesktopItems
    makeWrapper
  ];

  buildInputs = [
    adwaita-icon-theme
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gcc-unwrapped.lib
    glib
    gsettings-desktop-schemas
    gtk3
    libdrm
    libgbm
    libX11
    libxcb
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxkbcommon
    nspr
    nss
    pango
    systemdLibs
  ];

  # dlopen()ed at runtime, so auto-formatelf cannot discover them from
  # DT_NEEDED; list them here to force them onto every payload's RUNPATH.
  runtimeDependencies = [
    libayatana-appindicator
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    pipewire
    wayland
  ];

  desktopItems = [ desktopItem ];

  unpackPhase = ''
    runHook preUnpack
    ${lib.getExe' bintools "ar"} x $src
    tar xf data.tar.xz
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Keep the upstream opt/ZCode layout so bundled libs (e.g. libffmpeg.so)
    # resolve next to the main binary.
    mkdir -p $out/lib $out/bin $out/share
    cp -a opt/ZCode $out/lib/ZCode
    cp -a usr/share/icons $out/share/icons

    chmod +x $out/lib/ZCode/zcode

    # auto-formatelf sets the interpreter and RUNPATHs. The wrapper only adds
    # the app dir (so the bundled GL/Vulkan libs find each other), xdg-utils on
    # PATH, and the icon/schema data dirs.
    makeWrapper "$out/lib/ZCode/zcode" "$out/bin/zcode" \
      --prefix LD_LIBRARY_PATH : "$out/lib/ZCode" \
      --suffix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    runHook postInstall
  '';

  passthru = {
    category = "AI Coding Agents";

    updater = mkUpdater (
      source.updater
      // {
        versionSource = {
          type = "text";
          url = "https://zcode.z.ai/en";
          # The homepage's download section carries the current release; anchor
          # on the pluginDownload key that immediately follows it so a changelog
          # entry can never shadow the latest version.
          regex = ''\\"version\\":\\"([0-9]+\.[0-9]+\.[0-9]+)\\"},\\"pluginDownload\\"'';
        };
      }
    );
  };

  meta = with lib; {
    description = "Agentic development environment (ADE) by Z.ai";
    homepage = "https://zcode.z.ai";
    changelog = "https://zcode.z.ai/en/changelog";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ imxyy1soope1 ];
    mainProgram = "zcode";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
