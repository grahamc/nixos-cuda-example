{ config, pkgs, ... }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    emacs24-nox
    pciutils
    file
    
    gnumake
    gcc

    cudatoolkit
  ];

  services.xserver.videoDrivers = [ "nvidia" ];

  systemd.services.nvidia-control-devices = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = "${pkgs.linuxPackages.nvidia_x11}/bin/nvidia-smi";
  };
	    
  nixpkgs.config.allowUnfree = true;
    
  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "15.09";

}

