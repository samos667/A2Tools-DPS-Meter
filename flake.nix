{
  description = "A2Tools DPS Meter - AION 2 DPS overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      inherit (pkgs) lib;

      nativeDeps = with pkgs; [
        pkg-config
        glib
        gtk3
        webkitgtk_4_1
        libsoup_3
        cairo
        pango
        gdk-pixbuf
        atk
        openssl
        libayatana-appindicator
        libpcap
        libxkbcommon
        libepoxy
      ];

      runtimeDeps = with pkgs; [
        webkitgtk_4_1
        gtk3
        glib
        libsoup_3
        openssl
        libpcap
        libxkbcommon
        libGL
        wayland
        libayatana-appindicator
      ];

      package = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
        pname = "a2tools-dps-meter";
        version = "2.0.66";

        src = lib.cleanSource ./.;

        cargoRoot = "src-tauri";
        buildAndTestSubdir = "src-tauri";

        cargoHash = "sha256-BB5qNDQpVHUo7PLxw3Z4vJoOXprt8vDht17HnKXmyrw=";

        npmDeps = pkgs.fetchNpmDeps {
          inherit (finalAttrs) src;
          hash = "sha256-zrJnBXNHOwkVpfKMbnPsvRM7dh4ktztEvC98DOf6Vf0=";
        };

        nativeBuildInputs = with pkgs; [
          pkg-config
          nodejs
          npmHooks.npmConfigHook
          wrapGAppsHook3
          makeWrapper
        ];

        buildInputs = nativeDeps;

        preBuild = ''
          mkdir -p public/i18n public/data public/src/data

          cp -r src/data/i18n/. public/i18n/
          cp src/data/skill_icons.json src/data/dot_skill_ids.json public/data/
          cp src/data/skill_icons.json src/data/dot_skill_ids.json public/src/data/
        '';

        # Let the Tauri CLI perform the production build.
        dontCargoBuild = true;
        dontCargoInstall = true;

        buildPhase = ''
          runHook preBuild

          npm run tauri -- build --no-bundle

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin
          install -Dm755 \
            src-tauri/target/release/a2tools-dps-meter \
            $out/bin/a2tools-dps-meter

          runHook postInstall
        '';

        cargoBuildFlags = [
          "--bin"
          "a2tools-dps-meter"
        ];

        doCheck = false;

        postInstall = ''
          mkdir -p $out/share/applications

          cat > $out/share/applications/a2tools-dps-meter.desktop <<EOF
          [Desktop Entry]
          Type=Application
          Name=A2Tools DPS Meter
          Comment=AION 2 DPS overlay
          Exec=$out/bin/a2tools-dps-meter
          Terminal=false
          Categories=Game;Utility;
          EOF

          wrapProgram $out/bin/a2tools-dps-meter \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeDeps}
        '';

        meta = {
          description = "Real-time DPS meter for AION 2";
          homepage = "https://github.com/taengu/A2Tools-DPS-Meter";
          license = lib.licenses.gpl3Only;
          platforms = [ "x86_64-linux" ];
          mainProgram = "a2tools-dps-meter";
        };
      });
    in
    {
      packages.${system} = {
        default = package;
        a2tools-dps-meter = package;
      };

      apps.${system}.default = {
        type = "app";
        program = "${package}/bin/a2tools-dps-meter";
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          cargo
          rustc
          rustfmt
          clippy
          nodejs
          pkg-config
        ];

        buildInputs = nativeDeps;

        LD_LIBRARY_PATH = lib.makeLibraryPath runtimeDeps;
      };
    };
}
