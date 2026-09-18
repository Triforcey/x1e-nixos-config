# Single-module build of the msm display driver (NixOS wiki pattern):
# rebuilds just msm.ko against the running kernel's dev tree instead of
# the full kernel — the fast iteration loop for the display campaign.
{ pkgs, lib, kernel }:

pkgs.stdenv.mkDerivation {
  pname = "msm-kernel-module";
  inherit (kernel) src version postPatch nativeBuildInputs;

  kernel_dev = kernel.dev;
  kernelVersion = kernel.modDirVersion;

  modulePath = "drivers/gpu/drm/msm";

  # the REG_DMA quiesce diagnostic (see dpu-regdma-quiesce.patch)
  patches = [ ./dpu-regdma-quiesce.patch ];

  buildPhase = ''
    BUILT_KERNEL=$kernel_dev/lib/modules/$kernelVersion/build

    cp $BUILT_KERNEL/Module.symvers .
    cp $BUILT_KERNEL/.config        .
    cp $kernel_dev/vmlinux          .

    make "-j$NIX_BUILD_CORES" modules_prepare
    make "-j$NIX_BUILD_CORES" M=$modulePath modules
  '';

  installPhase = ''
    make \
      INSTALL_MOD_PATH="$out" \
      XZ="xz -T$NIX_BUILD_CORES" \
      M="$modulePath" \
      modules_install
  '';

  meta = {
    description = "Qualcomm msm display kernel module (with REG_DMA quiesce)";
    license = lib.licenses.gpl2;
  };
}
