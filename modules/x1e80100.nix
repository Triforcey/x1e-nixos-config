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

  config =
    let
      enabled = lib.any (key: cfg.${key}.enable) (lib.attrNames devices);
    in
    lib.mkIf enabled (
      lib.mkMerge [
        # Set the default device tree based on hardware.<device>.enable
        (lib.mkMerge (
          lib.mapAttrsToList (key: device: {
            hardware.deviceTree.name = lib.mkIf cfg.${key}.enable (lib.mkDefault device.deviceTreeName);
          }) devices
        ))

        {
          # For some reason now after a systemd update it gets hung for 1.5 minutes
          # at boot waiting for the TPM... which we don't have a driver for. Work
          # around this by explicitly disabling TPM.
          systemd.tpm2.enable = false;

          boot.blacklistedKernelModules = [
            # Too buggy right now, too many kernel crashes.
            "qcom_iris"
          ];

          boot.initrd.includeDefaultModules = false;
          boot.initrd.systemd.tpm2.enable = false; # This also pulls in some modules our kernel is not build with.
          boot.initrd.availableKernelModules = lib.mkMerge [
            [
              # Definitely needed for USB:
              "usb_storage"
              "phy_qcom_qmp_combo"
              "phy_snps_eusb2"
              "phy_qcom_eusb2_repeater"
              "tcsrcc_x1e80100"

              "i2c_hid_of"
              "i2c_qcom_geni"
              "dispcc-x1e80100"
              "gpucc-x1e80100"
              "phy_qcom_edp"
              "panel_edp"
              "msm"
              "nvme"
              "phy_qcom_qmp_pcie"

              # Needed with the DP altmode patches
              "ps883x"
              "pmic_glink_altmode"
              "qrtr"
            ]

            (lib.mkIf cfg.lenovo-yoga-slim7x.enable [
              "panel_samsung_atna33xc20"
            ])

            (lib.mkIf cfg.lenovo-thinkpad-t14s.enable [
              # Needed for t14s LCD display
              "pwm_bl"
              "leds_qcom_lpg"

              # Needed for USB
              "phy_nxp_ptn3222"
              "phy_qcom_qmp_usb"

              # Kernel 7.1.x adds the t14s HDMI port to the device tree:
              # mdss_dp2 (ae9a000) -> aux_bridge -> rtd2171 (simple_bridge) ->
              # hdmi-connector (display_connector). msm's component bind waits
              # for the complete bridge chain of every DP controller, so
              # without these the internal panel stays dark for all of stage 1
              # (e.g. while typing the LUKS passphrase).
              "simple_bridge"
              "display_connector"
              "mux_gpio"
              "reset_gpio"
              "gpio_shared_proxy"
            ])
          ];

          boot.kernelParams = lib.mkMerge [
            [
              # pd_ignore_unused / clk_ignore_unused were removed 2026-09-15
              # and boot-verified on the Yoga Slim 7x (fertile-forge): the
              # kernel carries the PCIe link-retention series (v3) plus the
              # GCC sync_state patch below, so the late-init cleanup no
              # longer kills the bootloader-trained links — "Retaining PCIe
              # link" logged on BOTH pcie6a (NVMe) and pcie4 (WiFi), display
              # and all devices up, zero faults. Verified for the slim7x
              # only; T14s/ISO boots on this branch run without these params
              # unverified. If a boot regresses (panel through stage 1,
              # USB-C/DP, PCIe, audio), restore these two params — see
              # docs/removing-clk-pd-ignore-unused.md.

              # Linux local privilege escalation using algif_aead:
              # https://copy.fail/
              # Linux local privilege escalation using esp4, esp6, rxrpc:
              # https://github.com/V4bel/dirtyfrag
              "module_blacklist=algif_aead,esp4,esp6,rxrpc"
            ]

            (lib.mkIf cfg.lenovo-yoga-slim7x.enable [
              # Needed since 4c3d9c134892c4158867075c840b81a5ed28af1f ("arm64: dts: qcom:
              # x1e80100: Add debug uart to Lenovo Yoga Slim 7x"), I guess systemd picks
              # UART as the only console, and it does not output logs on the screen.
              "console=tty1"
            ])

            (lib.mkIf cfg.lenovo-thinkpad-t14s.enable [
              "mem=31G"
            ])
          ];

          hardware.deviceTree.enable = true;

          boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

          boot.initrd.extraFirmwarePaths = lib.mkMerge [
            # Adreno (a740 / gen70500) GPU firmware, needed by all x1e80100
            # devices. The msm driver is in availableKernelModules and probes
            # the GPU during stage 1, so without these the SQE load fails
            # there ("Direct firmware load for qcom/gen70500_sqe.fw failed
            # with error -2") and the GPU only comes up after switch-root
            # (~32 s later; observed 2026-09-15 on the slim7x: "loaded
            # qcom/gen70500_sqe.fw from new location" at 34.8 s). Kernel
            # 7.2.x requests the renamed gen70500_sqe.fw / gen70500_gmu.bin
            # (formerly a740_sqe.fw); all three ship in nixpkgs linux-firmware
            # zstd-compressed, and modules-closure.sh resolves them by
            # retrying with a .zst suffix.
            [
              "qcom/gen70500_sqe.fw"
              "qcom/gen70500_gmu.bin"
              "qcom/x1e80100/gen70500_zap.mbn"
            ]

            (lib.mkIf cfg.lenovo-thinkpad-t14s.enable [
              # Basically all of the x1e80100 modules. Avoids fw_load errors in initrd.
              "qcom/x1e80100/LENOVO/21N1/cdspr.jsn"
              "qcom/x1e80100/LENOVO/21N1/qcadsp8380.mbn"
              "qcom/x1e80100/LENOVO/21N1/adspua.jsn"
              "qcom/x1e80100/LENOVO/21N1/battmgr.jsn"
              "qcom/x1e80100/LENOVO/21N1/adsps.jsn"
              "qcom/x1e80100/LENOVO/21N1/qcdxkmsuc8380.mbn"
              "qcom/x1e80100/LENOVO/21N1/qccdsp8380.mbn"
              "qcom/x1e80100/LENOVO/21N1/adspr.jsn"
              "qcom/x1e80100/LENOVO/21N1/adsp_dtbs.elf"
              "qcom/x1e80100/LENOVO/21N1/cdsp_dtbs.elf"
              "qcom/x1e80100/adsp.mbn"
              "qcom/x1e80100/adsp_dtb.mbn"
            ])

            (lib.mkIf cfg.lenovo-yoga-slim7x.enable [
              # Same set as the T14s above, for the slim7x board paths. The
              # slim7x DTB (via the Linaro cherry-picks) overrides the GPU
              # zap-shader firmware-name to the per-board
              # qcom/x1e80100/LENOVO/83ED/qcdxkmsuc8380.mbn; without it in
              # the initrd the GPU half-initializes in stage 1 (SQE+GMU
              # load, then "Unable to load ... qcdxkmsuc8380.mbn" -2, "gpu
              # hw init failed"), and the display renders recognizable but
              # corrupted frames (observed 2026-09-15 on the first 7.2
              # flake-kernel boot of fertile-forge).
              "qcom/x1e80100/LENOVO/83ED/cdspr.jsn"
              "qcom/x1e80100/LENOVO/83ED/qcadsp8380.mbn"
              "qcom/x1e80100/LENOVO/83ED/adspua.jsn"
              "qcom/x1e80100/LENOVO/83ED/battmgr.jsn"
              "qcom/x1e80100/LENOVO/83ED/adsps.jsn"
              "qcom/x1e80100/LENOVO/83ED/qcdxkmsuc8380.mbn"
              "qcom/x1e80100/LENOVO/83ED/qccdsp8380.mbn"
              "qcom/x1e80100/LENOVO/83ED/adspr.jsn"
              "qcom/x1e80100/LENOVO/83ED/adsp_dtbs.elf"
              "qcom/x1e80100/LENOVO/83ED/cdsp_dtbs.elf"
              "qcom/x1e80100/adsp.mbn"
              "qcom/x1e80100/adsp_dtb.mbn"
            ])
          ];

          # Upstream linux-firmware (still true in the 20260810 snapshot used
          # by nixpkgs) never received the Yoga Slim 7x CDSP device-tree blob.
          # The kernel's x1e80100-yoga-slim7x.dts declares the CDSP as split
          # firmware: "qcom/x1e80100/LENOVO/83ED/qccdsp8380.mbn" +
          # "qcom/x1e80100/LENOVO/83ED/cdsp_dtbs.elf", but Lenovo's April 2025
          # linux-firmware submission (upstream commit c0a41b80, "qcom:
          # x1e80100: Support for Lenovo Yoga Slim 7 Snapdragon platform")
          # shipped the ADSP pair only (qcadsp8380.mbn + adsp_dtbs.elf); no
          # later commit ever added the 83ED cdsp_dtbs.elf. Observed on kernel
          # 7.2.4 (2026-09-15 dmesg, stage 2 at ~33.4 s — qcom_q6v5_pas is not
          # in the initrd module list, so this is a rootfs-load, NOT an initrd
          # firmware gap; the runtime search path is the NixOS merged
          # hardware.firmware env, which the kernel reaches via the
          # firmware_class.path module param):
          #
          #   qcom_q6v5_pas 32300000.remoteproc: Direct firmware load for
          #     qcom/x1e80100/LENOVO/83ED/cdsp_dtbs.elf failed with error -2
          #   remoteproc remoteproc1: Failed to load program segments: -2
          #
          # The CDSP (Hexagon compute / DSP offload) then silently never
          # starts; ADSP (audio) is unaffected. Fix by shipping the file via
          # hardware.firmware, which lands in that merged env.
          #
          # Stopgap: reuse the T14s (21N1) cdsp_dtbs.elf. That blob is the
          # CDSP firmware's own device-tree fragment (SoC-level resource
          # description) and the T14s is the closest same-SoC Lenovo board,
          # but every board does get its own adsp_dtbs.elf, so a real 83ED
          # build may differ. Drop this override once Lenovo publishes the
          # genuine 83ED cdsp_dtbs.elf upstream. Always emit the uncompressed
          # file: depending on the nixpkgs snapshot, pkgs.linux-firmware
          # ships either plain files or zstd-compressed ones, so handle both
          # at build time.
          hardware.firmware = lib.mkIf cfg.lenovo-yoga-slim7x.enable [
            (pkgs.runCommand "x1e80100-yoga-slim7x-cdsp-dtb"
              {
                nativeBuildInputs = [ pkgs.zstd ];
              }
              ''
                fwdir=${pkgs.linux-firmware}/lib/firmware/qcom/x1e80100/LENOVO/21N1
                outdir=$out/lib/firmware/qcom/x1e80100/LENOVO/83ED
                mkdir -p $outdir
                if [ -e "$fwdir/cdsp_dtbs.elf.zst" ]; then
                  zstd -dc "$fwdir/cdsp_dtbs.elf.zst" > $outdir/cdsp_dtbs.elf
                else
                  install -m 0444 "$fwdir/cdsp_dtbs.elf" $outdir/cdsp_dtbs.elf
                fi
              '')
          ];

          # Point libcamera at the ov02c10 IPA tuning file for the webcam sensor.
          # This is mainly to remove green tint, but can be tweaked further.
          environment.sessionVariables.LIBCAMERA_IPA_CONFIG_PATH = [
            "${pkgs.runCommand "libcamera-ipa-configs" { } ''
              mkdir -p $out/simple
              cp ${./ov02c10.yaml} $out/simple/ov02c10.yaml
            ''}"
          ];
        }
      ]
    );
}
