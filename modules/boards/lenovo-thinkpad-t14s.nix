# Lenovo ThinkPad T14s Gen 6 (21N1) board hardware: initrd modules and
# firmware, kernel params.
{
  config,
  lib,
  ...
}:

let
  cfg = config.hardware.lenovo-thinkpad-t14s;
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      boot.initrd.availableKernelModules = [
        # LCD backlight
        "pwm_bl"
        "leds_qcom_lpg"

        # USB PHYs
        "phy_nxp_ptn3222"
        "phy_qcom_qmp_usb"

        # The t14s device tree chains mdss_dp2 -> aux_bridge ->
        # simple_bridge -> hdmi-connector; msm waits for the full bridge
        # chain of every DP controller, so without these the internal panel
        # stays dark through stage 1 (e.g. while typing the LUKS passphrase).
        "simple_bridge"
        "display_connector"
        "mux_gpio"
        "reset_gpio"
        "gpio_shared_proxy"
      ];

      boot.kernelParams = [
        "mem=31G"
      ];

      boot.initrd.extraFirmwarePaths = [
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
      ];
    }
  ]);
}
