{ pkgs ? import <nixpkgs> {} }:

let fhs = pkgs.buildFHSUserEnv {
        name = "cuda-env";
        targetPkgs = pkgs: with pkgs;
               [ git
                 gitRepo
                 gnupg
                 autoconf
                 curl
                 procps
                 gnumake
                 utillinux
                 m4
                 gperf
                 unzip
                 cudatoolkit
                 linuxPackages.nvidia_x11
                 libGLU_combined
		 xorg.libXi xorg.libXmu freeglut
                 xorg.libXext xorg.libX11 xorg.libXv xorg.libXrandr zlib 
		 ncurses5
		 stdenv.cc
		 binutils
                ];
          multiPkgs = pkgs: with pkgs; [ zlib ];
          runScript = "bash";
          profile = ''
                  export CUDA_PATH=${pkgs.cudatoolkit}
                  # export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib
		  export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
		  export EXTRA_CCFLAGS="-I/usr/include"
            '';
          };
in pkgs.stdenv.mkDerivation {
   name = "cuda-env-shell";
   nativeBuildInputs = [ fhs ];
   shellHook = "exec cuda-env";
}
