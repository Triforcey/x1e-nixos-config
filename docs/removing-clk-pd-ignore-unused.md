# Dropping `pd_ignore_unused` / `clk_ignore_unused`

This documents why the two boot params existed on X1E80100, what state our
kernel is in today, and the exact procedure used to boot-test removing them.

## STATUS: REMOVED and boot-verified (2026-09-15, Yoga Slim 7x)

The params are gone from this branch. The removal rides on two kernel
changes carried in `x1e80100-linux`:

1. The PCIe link-retention series (v3, cherry-picked): the
   bootloader-trained links survive qcom-pcie probe without PERST# /
   retraining — `Retaining PCIe link` logged on **both** pcie6a (NVMe)
   and pcie4 (WiFi).
2. The GCC sync_state patch (`packages/gcc-sync-state.patch`): the
   bootloader-enabled GCC clocks are preserved through `late_init` —
   closing the probe-deferral gap that boot-looped the first removal
   attempt (stage-1 hang, SBSA watchdog resetting every 10 min) — and
   the still-unclaimed clocks are gated from the driver's sync_state
   callback once all DT consumers have probed.

Boot-test evidence (fertile-forge, kernel 7.2.0, cmdline without either
flag): display clean through stage 1 and the desktop (after the
separately-documented initrd zap-shader firmware fix), all three PCIe
devices up, EC/ADSP/CDSP up, audio + WiFi working, zero SMMU faults and
zero GPU/DPU errors in the journal.

**Scope caveat**: verified on the Yoga Slim 7x only. T14s and ISO boots
on this branch run without the params unverified — the revert is a
one-commit `git revert` if a boot regresses.

**Remaining validation**: soak time, suspend/resume, USB-C/DP altmode,
and the `genpd_summary` power measurement vs the with-params baseline
(the ~2-4 W claim).

### Final state (2026-09-16): sync_state complete, 7/7 providers

The last two blockers were also removed:

- **`qcom_iris` was blacklisted** in this module (upstream "too buggy"
  comment, written against 6.x). Un-blacklisted: kmod honors blacklists
  on every autoload path — which is why manual modprobe worked while
  boot-time loading never did. The module now loads at boot via
  `boot.kernelModules` and binds via the sm8550 fallback compatible.
  V4L2 M2M decoder/encoder nodes exist.
- **The driverless GMU node** got a bind-only stub driver
  (`packages/gmu-stub.patch`), registered via the adreno driver hooks
  (a first attempt with module_platform_driver collided with msm_drv.o
  in the single msm module — see git history).

Result at idle (fertile-forge, kernel 7.2.0, cmdline still flag-free):

- **All seven providers `state_synced=1`**: gcc, gpucc, video_cc,
  rpmhpd, and the three qnoc interconnects. Zero pending sync_states.
- **28 platform devices runtime-suspended at idle**, including the
  GPU, the GMU itself, the iris codec, the RPMh resource controller, an
  SMMU, all three DP controllers, four audio codecs, two SoundWire
  links and the camera ISP/CCI.
- Settled idle draw: **5.82 W** (5.03–7.11 W over 12 samples) vs
  6.78 W measured mid-migration and a 5–7 W with-params baseline. The
  ~1 W delta vs baseline is smaller than the 2–4 W projection because
  the remaining draw is peripheral runtime-PM holds (USB controllers,
  NVMe, WiFi — all runtime-active), which the next work items target.

### RESOLVED (was): gcc/gpucc sync_state blocked by the driverless GMU

Superseded by the GMU stub driver (2026-09-16). The analysis below is
kept because it documents why `fw_devlink.sync_state=timeout` would be
unsafe on this platform:

After iris binding unblocked video_cc/rpmhpd/interconnects
(2026-09-16), `gcc` and `gpucc` remain `state_synced=0`:
`sync_state() pending due to 3d6a000.gmu`. The GMU DT node
(`qcom,adreno-gmu-x185.1`) has **no driver by design** in mainline (the
adreno GPU driver consumes the node directly), so fw_devlink never sees
it probe and gcc/gpucc keep their preserved boot state indefinitely -
equivalent to `clk_ignore_unused` scoped to those two providers.

Upstream's `fw_devlink.sync_state=timeout` boot param (drivers/base/core.c)
looks tempting but is **unsafe here**: it forces sync_state from
`fw_devlink_probing_done()` at the end of kernel init - before NixOS
stage-1 udev loads the PCIe/DPU modules - which re-creates the original
late-init failure mode (display dies before the LUKS prompt).

Candidate fixes, in order of preference:
1. Upstream: fw_devlink handling for consumers that will never probe
   (fire sync_state only after the *last module load* / at an explicit
   userspace-triggered point).
2. Local: a minimal stub platform driver matching
   `qcom,adreno-gmu-x185.1` (bind, return 0) so the consumer completes
   probing; the adreno driver reads the GMU node via of_parse and does
   not require it to be driverless. Needs verification that binding the
   node does not interfere with a7xx bring-up.

## Why the params exist

At `late_initcall`, the common clock framework (`clk_disable_unused`) turns
off every clock that no driver has claimed, and the genpd core powers off
every unused power domain. On X1E80100, firmware hands over hardware that is
already on (display, PCIe links trained by UEFI, USB PHYs, EC…). Until the
real driver probes and votes for its clocks/domains, nothing protects those
resources — and drivers can probe *after* `late_init`, because they defer on
regulators and PHYs. The two params disable those late-init cleanups, which
keeps everything forced-on. Cost: roughly 2-4 W of idle power.

## Blocker status (previous investigation → today)

| Blocker from the investigation             | State on `x1e80100-linux` (v6.19 + Linaro cherry-picks) |
|--------------------------------------------|----------------------------------------------------------|
| Per-board clock tree not fully described   | Resolved in-tree: v6.19 `hamoa.dtsi` already wires the TCSR clkref gates into the PCIe/USB PHYs, and the Linaro cherry-pick range adds the DP PHY TCSR ref clock (0462f37e) and the USB SS1/SS2 ref clock fixes (3194ae5b). |
| Missing power domain consumers             | Resolved upstream: per the `link_retain` v2 cover letter (Chundru, 2026-05), "GENPD/power domains are no longer getting turned off with the latest kernel". `pd_ignore_unused` is likely the cheaper of the two to test-drop first. |
| PCIe link retention not wired              | Built: the `link_retain` v3 series is cherry-picked into `x1e80100-linux` (see `packages/pcie-linkret-v3-*.patch`). Patch 1/4 was applied upstream as 910b828b22b7; patches 2+3 were authored against a post-v6.19 `pcie-qcom.c` and were ported to v6.19; patch 4/4 enables `link_retain` for `qcom,pcie-x1e80100`. |

The result: with the cherry-picked series, the UEFI-trained NVMe link on
`pcie6a` is detected at probe time (LTSSM in L0/L1-idle), the controller skips
reset/PERST#/retraining, and the QMP PCIe PHY skips its no-csr reset when the
bootloader already brought it up. What the series does **not** fix is the
probe-deferral gap: if `qcom-pcie` still probes after `late_init`, unclaimed
clocks get gated before the driver votes — the series cover letter explicitly
says `clk_ignore_unused` is still needed for its "initial version". The final
upstream piece is clk sync-state / probe ordering work.

## Test procedure (on the machine)

### A. Live ISO boot test (no host changes, fully reversible)

1. Build the ISO, which runs the flake's own `x1e80100-linux` kernel
   (already carrying the link retention series):

   ```
   nix build .#lenovo-yoga-slim7x-iso
   ```

2. Write `result/iso/*.iso` to a USB stick and boot it on the Yoga Slim 7x.
3. At the systemd-boot menu press `e` and delete `pd_ignore_unused` and
   `clk_ignore_unused` from the kernel command line. Boot.
4. Verify (see checklist below). If the system is stable, repeat once with
   the params present and once without, comparing genpd/clk state (step 6 of
   the checklist).

### B. Permanent removal (only after A passes)

1. In `modules/x1e80100.nix`, delete the two params and update the comment to
   record the successful boot test (kernel version + date).
2. Rebuild the host generation and reboot. The host must run
   `x1e80100-linux` for the retention logic to be present; stock nixpkgs
   kernels (7.1/7.2 as of 2026-09) do not have the series yet.
3. Re-run the checklist and record idle power before/after:
   `powertop --time 60` (or read `/sys/class/power_supply/BAT*/power_now`
   over several minutes at the desktop).

If anything fails at any step, boot the previous generation (or re-add the
params at the boot menu) and file the failure details (dmesg around late
init) against the upstream series.

### Verification checklist

Run all of these with and without the params and diff:

1. **Stage 1 / display**: panel stays lit through LUKS unlock (ISO has no
   LUKS; watch that the console does not go dark after the console goes
   quiet — the upstream issue #177 failure mode).
2. **PCIe / NVMe**: `lspci` shows the NVMe controller (pcie6a) and the
   WCN7850 WiFi (pcie4); `dmesg | grep -i 'pcie\|nvme'` shows
   `Retaining PCIe link` for at least the NVMe controller and no
   `PHY`/`link training` errors.
3. **USB-C / DP altmode**: both ports enumerate devices; `ls /sys/class/drm`
   shows the DP connectors; plug a DP-altmode cable into each port.
4. **Audio**: `aplay -l`, play a test sound through speakers and over
   DisplayPort.
5. **genpd state**:

   ```
   cat /sys/kernel/debug/pm_genpd/genpd_summary
   ```

   Domains with no consumer (e.g. unused PHYs, unused GPU perf domains)
   should report `status: off`. Compare the count of `status: on` domains
   with-params vs without — the whole point of this work is that the number
   drops and the machine stays stable.

6. **Clock state**:

   ```
   cat /sys/kernel/debug/clk/clk_summary
   ```

   Confirm no `always_on` clock needed by the panel/USB/PCIe got gated (the
   TCSR clkref gates appear here with consumers once claimed).

7. **Stability**: leave the machine idle 15+ minutes, then suspend/resume
   once (`systemctl suspend`), then re-check 2-5.

## Follow-up validation (was: what still blocks permanent removal)

The removal itself is no longer blocked — sync_state was the missing
piece (absent in the qcom clock drivers as of v7.2 and linux-next;
`packages/gcc-sync-state.patch` implements it for the GCC provider).
Still open:

- The validation checklist above (soak, suspend/resume, USB-C/DP,
  power measurement).
- T14s / ISO boots without the params (untested).
- Upstreaming `packages/gcc-sync-state.patch` — it is candidate material
  for the "clk sync-state" work the `link_retain` series author named as
  the exit condition; when 7.3 lands with an upstream equivalent,
  rebase onto it and drop ours (see the comment in
  `modules/x1e80100.nix`).

## Why the patches cannot ride on the stock kernel without a rebuild

Checked on fertile-forge (nixpkgs `linuxPackages_latest`, 7.2.4, 2026-09-15):

- `CONFIG_PCIE_QCOM=y` — the PCIe controller driver (where the retention
  logic lives, patches 2-4) is **built into** the stock kernel. A built-in
  driver cannot be overridden by an injected out-of-tree `.ko` (module
  blacklisting does not affect built-ins either), so the
  "rebuild only the two modules via `boot.extraModulePackages`" shortcut is
  **not viable** for the controller half. Flipping it to `=m` is a kernel
  config change, which is itself a full kernel rebuild.
- `CONFIG_PHY_QCOM_QMP_PCIE=m` — the PHY driver (patch 1) *is* a module and
  could be replaced out-of-tree, but on its own it accomplishes nothing:
  the stock built-in controller still tears down and retrains the link.

So on the stock kernel the choice is binary: full rebuild with the patches
(the series should apply near-verbatim there — it was authored after v6.19),
or wait for the series to land upstream in 7.3 and ride the binary cache.
The fork's own `x1e80100-linux` kernel (which now carries the series) is the
only immediately-available kernel with retention.
