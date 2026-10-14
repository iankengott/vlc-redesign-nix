{
  description = "Nix package for dsojevic's VLC redesign (VLC 4.0 dev, Juxtopposed design)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: rec {
        vlc-redesign = pkgs.callPackage ./package.nix { };
        default = vlc-redesign;
      });

      apps = forAll (pkgs: rec {
        vlc-redesign = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.vlc-redesign}/bin/vlc";
        };
        default = vlc-redesign;
      });

      # Builds with whatever nixpkgs the consumer uses. If a library was renamed
      # there, prefer `packages` above, which uses the nixpkgs pinned in flake.lock.
      overlays.default = final: _prev: {
        vlc-redesign = final.callPackage ./package.nix { };
      };
    };
}
