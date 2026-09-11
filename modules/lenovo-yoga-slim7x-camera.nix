{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.lenovo-yoga-slim7x.camera;
in
{
  options.hardware.lenovo-yoga-slim7x.camera.enable = lib.mkEnableOption ''
    the Lenovo Yoga Slim 7x camera device-tree overlay.

    This overlay adds the CAMSS/CCI/CAMCC and OV02C10 camera device tree nodes
    on top of the kernel's bundled `x1e80100-lenovo-yoga-slim7x.dtb`.

    Enable this when using a stock kernel (e.g. `pkgs.linuxPackages_latest`)
    whose device tree still lacks the camera ISP wiring. Do *not* enable it
    when using this flake's own `x1e80100-linux` kernel, which already
    contains the camera nodes (cherry-picked from the Linaro arm64-laptops
    tree) — applying the overlay twice would conflict.
  '';

  config = lib.mkIf cfg.enable {
    hardware.deviceTree.enable = lib.mkDefault true;
    hardware.deviceTree.overlays = [
      {
        name = "lenovo-yoga-slim7x-camera";
        filter = "x1e80100-lenovo-yoga-slim7x.dtb";
        dtsFile = ../packages/lenovo-yoga-slim7x-camera.dtso;
      }
    ];

    # Kernel drivers for the camera stack (stock mainline kernels build these
    # as modules; they are auto-loaded via device tree compatible strings, but
    # list them for initrd-less early probing robustness).
    boot.kernelModules = [
      "camcc-x1e80100"
      "qcom_camss"
      "i2c_qcom_cci"
      "ov02c10"
    ];
  };
}
