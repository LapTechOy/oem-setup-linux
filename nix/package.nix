{ lib
, stdenv
, cmake
, ninja
, pkg-config
, qtbase
, qtdeclarative
, qtsvg
, qttools
, wrapQtAppsHook
}:

stdenv.mkDerivation {
  pname = "oem-setup-linux";
  version = "1.0.0";

  src = lib.cleanSource ../.;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qttools
    wrapQtAppsHook
  ];

  buildInputs = [
    qtbase
    qtdeclarative
    qtsvg
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
  ];

  meta = {
    description = "First-boot OEM setup wizard for Linux";
    mainProgram = "oem-setup-gui";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
