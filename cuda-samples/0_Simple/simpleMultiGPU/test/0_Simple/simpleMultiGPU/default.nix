let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;
in rec {
  examplecuda = stdenv.mkDerivation rec {
    name = "example-cuda";
    src = ./.;
    buildInputs = [ pkgs.cudatoolkit ];

    preBuild = ''
      export CUDA_PATH="${pkgs.cudatoolkit}"
    '';

    installPhase = ''
      ls -la
    '';
  };
}