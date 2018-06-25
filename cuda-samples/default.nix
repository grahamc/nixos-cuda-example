let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;
in rec {
  examplecuda = stdenv.mkDerivation rec {
    name = "example-cuda";
    src = ./.;
    buildInputs = [ pkgs.cudatoolkit pkgs.linuxPackages.nvidia_x11 pkgs.makeWrapper ];

    preBuild = ''
      export CUDA_PATH="${pkgs.cudatoolkit}"
    '';

    installPhase = ''
      mkdir -p "$out/bin"
      cp -r ./bin/*/*/release/* "$out/bin"

      for file in `ls $out/bin | grep -v '\.'`; do
      	  echo "$file";
	  wrapProgram "$out/bin/$file" \
	              --prefix LD_LIBRARY_PATH ":" "${pkgs.linuxPackages.nvidia_x11}/lib"
      done
    '';


  };
}
