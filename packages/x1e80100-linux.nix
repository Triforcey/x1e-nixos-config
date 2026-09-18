{
  lib,
  fetchFromGitHub,
  buildLinux,
  linuxPackagesFor,
  ...
}:

let
  # Linaro arm64-laptops distro-integration commits to cherry-pick onto the
  # v7.2 base: branch qcom-laptops, tip 4236b993, rebased by Linaro onto
  # Linux 7.0 (028ef9c9). 85 commits in 028ef9c9..4236b993; these 75 apply
  # cleanly with --empty=drop. The 10 skipped ones (verified 2026-09-15,
  # see the hook comment) are either x1e-irrelevant (venus SM8350/SC8280XP)
  # or already upstreamed in mainline 7.2 in evolved form (PCI D3cold
  # series).
  linaroPickShas = ''
    81fb363eba83ed5a193837ab5db0b4ae6177b28b
    ae39466b5640c8fe5d6ab9f48f1a8050e7fe58c7
    ae0b28b8f4a18b4a04dcca25016d5f75628361a4
    ced8998d3a6f519761a5850d4a31a0c574eb9b3f
    4b038e885b631d2bf41be90cd33d7e040bfeb586
    5b76ead8fd9e1c9cc4587f2b2d2840357d29c377
    38e57eeca31712f2a0e099a0a32ae2d4cde86f6c
    f6a2c135fef96bd57ff394a668b020c44b330680
    c7d2b69dc486318ab08b23e53da83bf873d9161a
    1e30e736de22b0dffb5cb9e5e2cfe2be4590c2b8
    f61355a1ec289c5370691b29c0f04e664663a480
    77b1b6a353f4dc803b22a1110e596650e12354fb
    1c5e2f7dfde28add702cf4bbf50d00e21e484961
    e57450e55c99bf9a9104e871d995dfdc9e2c817b
    05580e8a228adf523cd52a06685c8c0357ab0adf
    86e13a208d2f0be67dd660e8de668d9b14a94b0d
    6a38f69676340bc218c6d4003bdebc4aea8cc031
    4c4fe97e8a34b335524fd5314017feb938233956
    9b00f7c37872604a65904f6524f7bf0367e898df
    00e21f362ebec659a81b0d210fdcdc391230f899
    c456a8b33c86a64ad8f089632d96722bb965d567
    9cd9be0cfde4ac9342a0f46896089c9e222bd7d6
    27f4e85746d0b5ed8cc06b01aa3cab81ba22c72e
    8157f84f9aea9a410105245ca4a0289ea73d4ca6
    d7ccf875ebadf78b7d47724df6bc37a4eceb784b
    dc31588efdc448200a73893b757a4f66ab3c4819
    708f04cc3cb4168c9054f193f5a0ccd5b6d20649
    78844e56338a3365664479a66727168a77caf7f8
    93199b1df9fe3e70868385ed5c865a51246ddd06
    4a1d5eb260fb875785af22171f9ef65f9a6afba5
    6522995b56b846c13aa98106f73b996e73695860
    72ff5ea3a29fd48e7d584365177a5cc9263883d7
    c3de90c011e49b4c61cc3fc639cdc1c50ecb6a97
    c7bc7731b355dd212c055f750ec12e3aee344886
    d79e44083197b263ee59dc3521a2b16ad2a12bd8
    493d746f75b211d19b30e0f01ac2fb6a4656201b
    989810688f17bdf41719b83c0442711a31a88306
    6cbd5bb76661286556e284376d418869a0eb7f9c
    79632f855b0ef0219cb099f9fc75248ce417ba2a
    813459fe7c78db22cc0382d95371e2d02aeeeb23
    69821e4dd79480b9382679fbb0c823d895feac26
    8f7769252606ab9138caefa398ce0f452358825a
    f16592725bfc503f3a644590ae8b6280dc7c2c58
    28ebeb6c89217f8e13c321ffb24bf9fc6942348e
    0ea98a8976b936040a56e7a99f54726863953bc7
    c9c866e22e00b0a164ef8ec3b3dedefd4bf205ca
    f09489e24500c6cdaa11e35d528b5bb4d333ada5
    b8021af229bd39d68864b73a08e8fc4e6c1befbe
    e48b4e9139df92a2368cf11af63694f0579f57ca
    525ab493ca09bfbcb3544ad557f69155f419c879
    7bedcdb1ae68738630e5de2d77e243fd557b238f
    01faffba0a60c37931e1821e55d3bd69194ea0a4
    a94e66bb7e6836329bbab4917cd0b63be9b31bc0
    7da0883744060cbff10c637dcb985e90e8d13e58
    540be51ecedbd38c7ee69b2efd69bcaa41400d19
    5709bda6712f1a145f5a6bcad8ddddd9cd4ba0db
    169310c7af286d100c82ce8fae969de156eaa150
    0ba67a96cf1891552bdbe5fdaa1770396d2e71f6
    22dcf9dc4c4245dff4cda3af489ed2d0dac46c90
    26a4354eb33e5e4c2fd88bc2286ea703379af10c
    cdb8d28ed3f34f5779820e728f45b2d23714dfc2
    d2130609eaefe99416cb6455ee0ee763baba8fe0
    acd3a58c568ec152f581564be1921dc9fe3b84d0
    2573aa51a293e76a8f87bee2031721f87457bd0e
    4f4040404e158db5d76dfd0d598e9bff2751fddd
    e90a55f7c1815ccc952900eb850a6c020fcfb472
    46ff4b3fd30e8694b9e197771842400718d9303a
    428c59f6a52504f82bc4c1191eb388afeb6364a1
    3d8c39e8966c9bbca89543c59f3131cf3a569c05
    455be26ca3500157a6db9d82de74dba1f3146bba
    3faa84e8a626b67157660f28ac1488fdaa32ddb5
    6eade2d5308e08cac6bd584ad1b14083aa29d379
    bbe81836e612dfcc229a4319e2a0a6eaccb603f5
    b2234d6053d8e5b7ad757553c2f57d54830552f3
    4236b9933aa13cb7a3572bc943ad7e3b42f5de5d
  '';
in
linuxPackagesFor (buildLinux {
  src = fetchFromGitHub {
    owner = "torvalds";
    repo = "linux";
    tag = "v7.2";
    forceFetchGit = true;
    preFetch = "export ${lib.toShellVar "NIX_PREFETCH_GIT_CHECKOUT_HOOK" ''
      pushd "$dir"
      git config user.name "nix"
      git config user.email "nix"

      # Linaro arm64-laptops distro-integration tree (branch qcom-laptops,
      # tip 4236b993, based on Linux 7.0). Cherry-pick the laptop patches
      # mainline does not have yet onto the v7.2 base: camera stack
      # (CAMSS/CCI/CAMCC/CSI-PHY + per-board sensor/PMIC DT), pmic-glink /
      # ucsi suspend fixes, ASPM link-state API + ath11k/ath10k users,
      # qrtr/mhi sync, smp2p, qcom_laptops bits.
      #
      # 85 commits in 028ef9c9..4236b993, 10 skipped (conflict with
      # mainline 7.2, verified 2026-09-15):
      #   2112474f8, 48363a207, d57936fdc   media: venus SM8350/SC8280XP
      #                                     (not x1e80100 hardware)
      #   9b347af8b, 908ec5c0b, 79ac38623,  PCI D3cold series (mainline
      #   aac9d78eb, d7dc9d6ed, bab09f2c0,  took an evolved version in
      #   bfc2579a0                         7.2)
      # If the Linaro branch advances far, --depth 200 may need raising to
      # reach the oldest pinned SHA.
      git fetch 'https://gitlab.com/Linaro/arm64-laptops/linux.git' --depth 200 qcom-laptops

      echo "${linaroPickShas}" | xargs git cherry-pick --empty=drop

      popd
    ''}";

    hash = "sha256-R1R690lylRXm9eYghYzhqbgWIOrnBPmByoplvrZzl3U=";
  };
  version = "7.2.0";

  kernelPatches = [
    # PCIe link retention series v3 (Chundru, 2026-07, under review for
    # 7.3). Prerequisite for dropping the pd_ignore_unused /
    # clk_ignore_unused boot params; see
    # docs/removing-clk-pd-ignore-unused.md. Applies verbatim on v7.2's
    # pcie-qcom.c (the parse_perst refactor the series was authored
    # against is mainline there).
    {
      name = "PCI: qcom: link retention v3 (1/4): phy skip reset if already up";
      patch = ./pcie-linkret-v3-1-phy-skip-reset.patch;
    }
    {
      name = "PCI: qcom: link retention v3 (2/4): keep PERST# GPIO state as-is during probe";
      patch = ./pcie-linkret-v3-2-perst-asis.patch;
    }
    {
      name = "PCI: qcom: link retention v3 (3/4): retain bootloader-trained link";
      patch = ./pcie-linkret-v3-3-link-retain.patch;
    }
    {
      name = "PCI: qcom: link retention v3 (4/4): enable for x1e80100";
      patch = ./pcie-linkret-v3-4-x1e80100-enable.patch;
    }

    # Keep the bootloader-enabled GCC clocks alive until all their DT
    # consumers have probed (fw_devlink sync_state), then gate the
    # still-unclaimed ones via the driver's sync_state callback. Combined
    # with the link retention series this replaces the
    # clk_ignore_unused / pd_ignore_unused boot params. Our own patch —
    # the qcom clock drivers have no sync_state support upstream (checked
    # v7.2 and linux-next 2026-09-15); candidate for upstream submission.
    {
      name = "clk: qcom: gcc: Preserve the boot clock state until sync_state";
      patch = ./gcc-sync-state.patch;
    }

    # The GMU DT node has no driver upstream (the a7xx GPU driver consumes
    # the node via of_parse_phandle), so fw_devlink never counts it probed
    # and gcc/gpucc sync_state stays pending forever - keeping their
    # preserved boot clock state on. A bind-only stub completes the
    # consumer set and lets the deferred cleanup run.
    {
      name = "drm/msm/adreno: Add a GMU stub driver for X1E80100";
      patch = ./gmu-stub.patch;
    }

    # EXPERIMENTAL (2026-09-16), NOT ENABLED: USB host-mode runtime PM.
    # dwc3_core_probe() pm_runtime_forbid()s the controller and never
    # lifts it, so the USB tree never autosuspends. This patch allows
    # runtime PM once the role resolves to host. Gated on the live sysfs
    # experiment passing: echo auto on the three *.usb devices and three
    # xhci-hcd.* children, verify they suspend AND that USB wake works
    # (plug a device, check it enumerates). Uncomment to include.
    # {
    #   name = "usb: dwc3: allow runtime PM for host-mode controllers";
    #   patch = ./dwc3-host-rpm.patch;
    # }

    # EC: DTS node only — the driver is mainline on 7.2 (EC_QCOM_HAMOA,
    # binds "qcom,hamoa-crd-ec", proven on fertile-forge via the EC
    # overlay).
    {
      name = "arm64: dts: qcom: x1e80100-lenovo-yoga-slim7x: add embedded controller";
      patch = ./lenovo-yoga-slim7x-ec-dts.patch;
    }

    # Camera fixups (the camera DT/driver content itself arrives via the
    # Linaro cherry-picks).
    {
      name = "arm64: dts: qcom: x1e80100-slim7x: align regulators with AeoB specification";
      # See: https://gitlab.com/Linaro/arm64-laptops/linux/-/issues/9
      patch = ./lenovo-yoga-slim7x-camera-regulators-fix.patch;
    }

    # The camera sensor's rotation is left unset: the native readout is
    # upright on this panel mounting, and libcamera treats a missing/0
    # rotation as no transform. A rotation=<180> patch was tried and
    # produced upside-down frames (see x1e-yoga-book-porting.md).

    # Gamma LUT / DSPP GC: the old 6.19-era patch (gamma-lut.patch) is gone
    # for good — the feature was merged mainline between 6.19 and 7.2
    # (dpu_crtc.c has _dpu_crtc_get_gc_lut/setup_gc, and the x1e80100
    # catalog's DSPPs use sdm845_dspp_sblk which carries the .gc block).
    # Nothing to patch.
  ];

  # TODO: Look into the errors and remove this.
  ignoreConfigErrors = true;

  structuredExtraConfig = with lib.kernel; {
    VIRTUALIZATION = yes;
    KVM = yes;
    MAGIC_SYSRQ = yes;

    # EC: mainline driver (the 6.19-era EC_LENOVO_YOGA_SLIM7X out-of-tree
    # driver is replaced by it on 7.2).
    EC_QCOM_HAMOA = module;

    # Stuff to reduce compile times.
    ACPI = no;

    HOTPLUG_PCI = no;

    ARCH_ACTIONS = no;
    ARCH_AIROHA = no;
    ARCH_SUNXI = no;
    ARCH_ALPINE = no;
    ARCH_APPLE = no;
    ARCH_AXIADO = no;
    ARCH_BCM = no;
    ARCH_BCM2835 = no;
    ARCH_BCM_IPROC = no;
    ARCH_BRCMSTB = no;
    ARCH_BERLIN = no;
    ARCH_BLAIZE = no;
    ARCH_CIX = no;
    ARCH_EXYNOS = no;
    ARCH_SPARX5 = no;
    ARCH_K3 = no;
    ARCH_LG1K = no;
    ARCH_HISI = no;
    ARCH_KEEMBAY = no;
    ARCH_MEDIATEK = no;
    ARCH_MESON = no;
    ARCH_MVEBU = no;
    ARCH_NXP = no;
    ARCH_LAYERSCAPE = no;
    ARCH_MXC = no;
    ARCH_S32 = no;
    ARCH_MA35 = no;
    ARCH_NPCM = no;
    ARCH_REALTEK = no;
    ARCH_ROCKCHIP = no;
    ARCH_SEATTLE = no;
    ARCH_INTEL_SOCFPGA = no;
    ARCH_SOPHGO = no;
    ARCH_STM32 = no;
    ARCH_SYNQUACER = no;
    ARCH_TEGRA = no;
    ARCH_TESLA_FSD = no;
    ARCH_SPRD = no;
    ARCH_THUNDER = no;
    ARCH_THUNDER2 = no;
    ARCH_UNIPHIER = no;
    ARCH_VEXPRESS = no;
    ARCH_VISCONTI = no;
    ARCH_XGENE = no;
    ARCH_ZYNQMP = no;

    DRM_NOUVEAU = no;
    DRM_ETNAVIV = no;
    DRM_HISI_HIBMC = no;
    DRM_HISI_KIRIN = no;
    DRM_LIMA = no;
    DRM_PANFROST = no;
    DRM_PANTHOR = no;
    DRM_TIDSS = no;
    DRM_POWERVR = no;

    WLAN_VENDOR_ADMTEK = no;
    WLAN_VENDOR_ATMEL = no;
    WLAN_VENDOR_BROADCOM = no;
    WLAN_VENDOR_INTEL = no;
    WLAN_VENDOR_INTERSIL = no;
    WLAN_VENDOR_MARVELL = no;
    WLAN_VENDOR_MEDIATEK = no;
    WLAN_VENDOR_MICROCHIP = no;
    WLAN_VENDOR_PURELIFI = no;
    WLAN_VENDOR_RALINK = no;
    WLAN_VENDOR_REALTEK = no;
    WLAN_VENDOR_RSI = no;
    WLAN_VENDOR_SILABS = no;
    WLAN_VENDOR_ST = no;
    WLAN_VENDOR_TI = no;
    WLAN_VENDOR_ZYDAS = no;
    WLAN_VENDOR_QUANTENNA = no;
    SND_DRIVERS = no;
    SND_PCI = no;
  };
})
