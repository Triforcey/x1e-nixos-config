# Snapdragon X1E80100 SoC/CPU-level support: device options, default device
# tree, common initrd modules/firmware, and security kernel params.
# Board-specific hardware lives in boards/*.nix.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  devices = import ../devices.nix;
  cfg = config.hardware;
in
{
  options.hardware = lib.mapAttrs (_: device: {
    enable = lib.mkEnableOption "support for the ${device.displayName}";
  }) devices;

  imports = [
    ./boards/lenovo-yoga-slim7x.nix
    ./boards/lenovo-thinkpad-t14s.nix
  ];

  config =
    let
      enabled = lib.any (key: cfg.${key}.enable) (lib.attrNames devices);
    in
    lib.mkIf enabled (
      lib.mkMerge [
        # Default device tree based on hardware.<device>.enable
        (lib.mkMerge (
          lib.mapAttrsToList (key: device: {
            hardware.deviceTree.name = lib.mkIf cfg.${key}.enable (lib.mkDefault device.deviceTreeName);
          }) devices
        ))

        {
          # No TPM driver on this platform; the stock initrd waits for one at
          # boot, so disable it explicitly.
          systemd.tpm2.enable = false;

          boot.initrd.includeDefaultModules = false;
          boot.initrd.systemd.tpm2.enable = false; # This also pulls in some modules our kernel is not build with.
          boot.initrd.availableKernelModules = [
            # USB
            "usb_storage"
            "phy_qcom_qmp_combo"
            "phy_snps_eusb2"
            "phy_qcom_eusb2_repeater"
            "tcsrcc_x1e80100"

            # Input / display / storage
            "i2c_hid_of"
            "i2c_qcom_geni"
            "dispcc-x1e80100"
            "gpucc-x1e80100"
            "phy_qcom_edp"
            "panel_edp"
            "msm"
            "nvme"
            "phy_qcom_qmp_pcie"

            # DP altmode
            "ps883x"
            "pmic_glink_altmode"
            "qrtr"
          ];

          boot.kernelParams = [
            # pd_ignore_unused/clk_ignore_unused are gone: the kernel carries
            # PCIe link retention plus the GCC sync_state patch (see
            # docs/removing-clk-pd-ignore-unused.md). Verified on the slim7x;
            # restore the two params if a T14s/ISO boot regresses.

            # Deferred probes wait for their suppliers indefinitely: with the
            # default timeout=0, any deferred probe retried after initcalls
            # complete hard-fails (-ETIMEDOUT) — that killed the camera chain
            # (CCI/CSI2 -110) and iris (-110) on slow boots. -1 never
            # schedules the timeout work (drivers/base/dd.c).
            "deferred_probe_timeout=-1"

            # Kernel security module blacklist:
            # algif_aead (local privilege escalation, https://copy.fail/),
            # esp4/esp6/rxrpc (https://github.com/V4bel/dirtyfrag)
            "module_blacklist=algif_aead,esp4,esp6,rxrpc"
          ];

          hardware.deviceTree.enable = true;

          boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

          boot.initrd.extraFirmwarePaths = [
            # Adreno GPU firmware: the msm driver probes the GPU during stage 1
            # and fails without it ("Direct firmware load for
            # qcom/gen70500_sqe.fw failed with error -2"); with it the GPU is
            # up in stage 1. The gen70500_* files ship zstd-compressed in
            # nixpkgs linux-firmware; modules-closure resolves the .zst names.
            "qcom/gen70500_sqe.fw"
            "qcom/gen70500_gmu.bin"
            "qcom/x1e80100/gen70500_zap.mbn"
          ];
        }
      ]
    );
  # msm display module as a single-module package: carries the REG_DMA
  # quiesce diagnostic, rebuilds in ~2 min per fix instead of a full
  # kernel rebuild (NixOS wiki: patching a single in-tree kernel module).
  boot.extraModulePackages = [
    (pkgs.callPackage ../packages/msm-kernel-module.nix {
      kernel = config.boot.kernelPackages.kernel;
    })
  ];

}
