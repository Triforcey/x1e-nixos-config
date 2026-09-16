# Lenovo Yoga Slim 7x (83ED) board hardware: initrd modules and firmware,
# kernel params, and the CDSP device-tree firmware stopgap.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.hardware.lenovo-yoga-slim7x;
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      boot.initrd.availableKernelModules = [
        "panel_samsung_atna33xc20"
      ];

      boot.kernelParams = [
        # Since the debug UART landed in this board's device tree, systemd
        # picks the UART as the only console; force the screen back on.
        "console=tty1"
      ];

      boot.initrd.extraFirmwarePaths = [
        # Per-board DSP firmware set. The slim7x DTB (via the Linaro
        # cherry-picks) overrides the GPU zap-shader firmware-name to the
        # per-board qcdxkmsuc8380.mbn; without it in the initrd the GPU
        # half-initializes in stage 1 and the display corrupts.
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
      ];
    }

    # CDSP firmware stopgap: linux-firmware shipped the 83ED ADSP pair but
    # never the CDSP device-tree blob (cdsp_dtbs.elf), so the CDSP never
    # starts. Ship the T14s (21N1) blob under the 83ED path — it is the
    # CDSP firmware's SoC-level resource description and the closest
    # same-SoC board. Drop once Lenovo publishes the genuine 83ED blob;
    # emit it uncompressed (linux-firmware snapshots vary between plain
    # and zstd-compressed files).
    {
      hardware.firmware = [
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
    }

    # libcamera IPA tuning for the OV02C10 webcam sensor (removes green tint).
    {
      environment.sessionVariables.LIBCAMERA_IPA_CONFIG_PATH = [
        "${pkgs.runCommand "libcamera-ipa-configs" { } ''
          mkdir -p $out/simple
          cp ${../ov02c10.yaml} $out/simple/ov02c10.yaml
        ''}"
      ];
    }
  ]);
}
