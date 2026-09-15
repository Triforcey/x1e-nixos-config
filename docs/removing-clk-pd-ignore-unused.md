# Dropping `pd_ignore_unused` / `clk_ignore_unused`

This documents why the two boot params exist on X1E80100, what state our
kernel is in today, and the exact procedure to boot-test removing them on a
Yoga Slim 7x (or T14s) before making the removal permanent.

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

## What still blocks permanent removal

- Boot-test evidence from step A/B (this is hardware work; cannot be done
  from the build host).
- The upstream probe-deferral / clk sync-state fix, tracked as part of the
  `link_retain` series review (v3 cover letter, 2026-07: "Once it is resolved
  we can avoid those kernel command line arguments"). When 7.3 lands with
  that work, re-evaluate — upstream dropping the params on `main` is the
  signal to follow (see the comment in `modules/x1e80100.nix`).
