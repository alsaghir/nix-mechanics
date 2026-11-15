# Only the lines this example needs; your /etc/nixos/configuration.nix has
# many more.
{ config, pkgs, ... }:
{
  programs.firefox.enabled = true;

  system.stateVersion = "26.05";
}
