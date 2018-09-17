{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
   name = "cuda-env-shell";
   buildInputs = with pkgs;
                  [ git gitRepo gnupg autoconf curl
                    procps gnumake utillinux m4 gperf unzip
                    cudatoolkit linuxPackages.nvidia_x11
                    libGLU_combined
                    xorg.libXi xorg.libXmu freeglut
                    xorg.libXext xorg.libX11 xorg.libXv xorg.libXrandr zlib 
                    ncurses5 stdenv.cc binutils
                   ];
   shellHook = ''
      export CUDA_PATH=${pkgs.cudatoolkit}
      # export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib
		  export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
		  export EXTRA_CCFLAGS="-I/usr/include"
   '';          
}
