{
  description = "OEM setup Linux C++/Qt development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cmake
              ninja
              pkg-config
              clang-tools
              gdb
              just
              qt6.qtbase
              qt6.qtdeclarative
              qt6.qtsvg
              qt6.qttools
              qt6.wrapQtAppsHook
            ];

            shellHook = ''
              export CMAKE_GENERATOR=Ninja
              export QML_IMPORT_PATH="${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
              export QT_PLUGIN_PATH="${pkgs.qt6.qtbase}/lib/qt-6/plugins:${pkgs.qt6.qtsvg}/lib/qt-6/plugins"
            '';
          };
        });

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          default = pkgs.qt6Packages.callPackage ./nix/package.nix { };
        in
        {
          inherit default;
        });
    };
}
