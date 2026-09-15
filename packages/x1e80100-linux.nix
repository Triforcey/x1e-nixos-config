{
  lib,
  fetchFromGitHub,
  buildLinux,
  linuxPackagesFor,
  fetchpatch,
  fetchurl,
  b4,
  ...
}:

linuxPackagesFor (buildLinux {
  src = fetchFromGitHub {
    owner = "torvalds";
    repo = "linux";
    tag = "v6.19";
    forceFetchGit = true;
    nativeBuildInputs = [ b4 ];
    preFetch = "export ${lib.toShellVar "NIX_PREFETCH_GIT_CHECKOUT_HOOK" ''
      pushd "$dir"
      git config user.name "nix"
      git config user.email "nix"

      git fetch 'https://gitlab.com/Linaro/arm64-laptops/linux.git' --depth 106 19e59e1b39ad789a5bf90b0b9850bb11ca9f7ebb
      git cherry-pick --empty=drop 63804fed149a6750ffd28610c5c1c98cce6bd377..19e59e1b39ad789a5bf90b0b9850bb11ca9f7ebb

      # Collect some stats
      du -sh .git

      popd
    ''}";

    hash = "sha256-qElJ642reD/NX63qEBNDgFFVBWxO0zqQxWXDFHeqJu0=";
  };
  version = "6.19.0";

  kernelPatches = [
    {
      name = "rust: irq: add `'static` bounds to irq callbacks";
      patch = fetchpatch {
        url = "https://github.com/torvalds/linux/commit/621609f1e5ca43a75edd497dd1c28bd84aa66433.patch";
        hash = "sha256-78Nv3P2sWjGwpmHdUPbo6EAmcI6wthMRsmLpOKM8oCM=";
      };
    }

    {
      name = "Add slim7x EC driver";
      # From: https://lore.kernel.org/lkml/20241219200821.8328-1-maccraft123mc@gmail.com/
      patch = ./lenovo-yoga-slim7x-ec.patch;
    }

    # PCIe link retention series (link_retain v3, Krishna Chaitanya Chundru,
    # 2026-07, under review for 7.3; not merged upstream as of 2026-09).
    # Cherry-picked into this kernel so that the bootloader-trained PCIe link
    # (pcie6a NVMe on the Yoga Slim 7x) survives the qcom-pcie probe without
    # PERST# toggling / PHY re-init, as a prerequisite for dropping the
    # `clk_ignore_unused` boot param. See docs/removing-clk-pd-ignore-unused.md.
    # Patches 2+3 were authored against a newer pcie-qcom.c (post-v6.19
    # parse_perst/parse_ports refactoring) and were ported to v6.19; the port
    # is documented in the patch header.
    {
      name = "PCI: qcom: link retention v3 (1/4): phy skip reset if already up";
      patch = ./pcie-linkret-v3-1-phy-skip-reset.patch;
    }
    {
      name = "PCI: qcom: link retention v3 (2+3/4, ported to 6.19): retain bootloader link";
      patch = ./pcie-linkret-v3-2-3-ported-to-v6.19.patch;
    }
    {
      name = "PCI: qcom: link retention v3 (4/4): enable for x1e80100";
      patch = ./pcie-linkret-v3-4-x1e80100-enable.patch;
    }

    {
      name = "drm/dpu: Add support for DSPP GC block to enable Gamma LUT capability";
      patch = fetchurl {
        name = "9ee91c5748e83772dc3660077f9f415a453eeace.patch";
        url = "file://${./gamma-lut.patch}";
        hash = "sha256-tz82YWVkEShCj7HVJXi7KlyG3gmR+yjYcvS4JMch+sU=";
      };
    }

    # Camera fixups
    {
      name = "arm64: dts: qcom: x1e80100-slim7x: align regulators with AeoB specification";
      # See: https://gitlab.com/Linaro/arm64-laptops/linux/-/issues/9
      patch = ./lenovo-yoga-slim7x-camera-regulators-fix.patch;
    }
    {
      # Based on:
      # https://github.com/alexVinarskis/linux-x1e80100-zenbook-a14/pull/1
      # Apparently this option should be interpreted by userspace, so rotating
      # in the kernel should not be needed.
      name = "rotation = <180>;";
      patch = ./lenovo-yoga-slim7x-camera-rotation.patch;
    }
  ];

  # TODO: Look into the errors and remove this.
  ignoreConfigErrors = true;

  structuredExtraConfig = with lib.kernel; {
    VIRTUALIZATION = yes;
    KVM = yes;
    MAGIC_SYSRQ = yes;
    EC_LENOVO_YOGA_SLIM7X = module;

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
    ARCH_BCMBCA = no;
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
    ARCH_RENESAS = no;
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
