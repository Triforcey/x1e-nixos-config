{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.lenovo-yoga-slim7x.ec;
in
{
  options.hardware.lenovo-yoga-slim7x.ec.enable = lib.mkEnableOption ''
    the Lenovo Yoga Slim 7x embedded-controller device-tree overlay.

    This overlay adds the IT8987 embedded-controller node
    (`embedded-controller@76` on i2c5) on top of the kernel's bundled
    `x1e80100-lenovo-yoga-slim7x.dtb`. With the node present, an EC kernel
    driver notifies the EC when the host suspends and resumes. Without it the
    EC is never told about suspend: the keyboard backlight stays on and the
    suspend LED does not blink.

    Enable this when using a stock kernel (e.g. `pkgs.linuxPackages_latest`).
    On kernels >= 7.2 the mainline `qcom-hamoa-ec` driver binds to the node;
    make sure it is built (nixpkgs does not enable `CONFIG_EC_QCOM_HAMOA` by
    default — see the README). Do *not* enable this overlay when using this
    flake's own `x1e80100-linux` kernel, whose device tree already contains
    the EC node (via the slim7x EC kernel patch).
  '';

  config = lib.mkIf cfg.enable {
    hardware.deviceTree.enable = lib.mkDefault true;
    hardware.deviceTree.overlays = [
      {
        name = "lenovo-yoga-slim7x-ec";
        filter = "x1e80100-lenovo-yoga-slim7x.dtb";
        dtsFile = ../packages/lenovo-yoga-slim7x-ec.dtso;
      }
    ];

    # Kernel drivers for the embedded controller. They are auto-loaded via
    # device tree compatible strings, but list the possible module names for
    # initrd-less early probing robustness (which one exists depends on the
    # kernel: stock kernels >= 7.2 ship `qcom_hamoa_ec`, the flake's
    # `x1e80100-linux` kernel ships `qcom_x1e_it8987`).
    boot.kernelModules = [
      "qcom_hamoa_ec"
      "qcom_x1e_it8987"
    ];
  };
}
