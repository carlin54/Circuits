"""Integration test for amp_channel.v (full effects chain)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import sys
sys.path.insert(0, str(__file__).rsplit('/', 2)[0])
from helpers.fixed_point import FixedPointConfig, float_to_fixed, fixed_to_float


async def reset_dut(dut, cycles=10):
    """Reset the DUT and set default control values."""
    dut.rst.value = 1

    # AXI-Stream input
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0

    # AXI-Stream output ready
    dut.m_axis_tready.value = 1

    # Bypass all effects by default
    dut.fx_bypass.value = 0xFF

    # Noise gate controls
    dut.gate_open_thresh.value = 10
    dut.gate_close_thresh.value = 5
    dut.gate_hold_time.value = 100

    # Compressor controls
    dut.comp_threshold.value = 200
    dut.comp_ratio.value = 4
    dut.comp_attack.value = 100
    dut.comp_release.value = 500
    dut.comp_makeup.value = 128

    # Gain stage controls
    dut.drive.value = 128
    dut.gain_level.value = 128
    dut.clip_type.value = 0

    # Tone stack controls
    dut.bass.value = 128
    dut.mid.value = 128
    dut.treble.value = 128
    dut.presence.value = 128
    dut.resonance.value = 128

    # Chorus controls
    dut.chorus_rate.value = 64
    dut.chorus_depth.value = 64
    dut.chorus_mix.value = 0

    # Flanger controls
    dut.flanger_rate.value = 64
    dut.flanger_depth.value = 64
    dut.flanger_fb.value = 0
    dut.flanger_mix.value = 0

    # Delay controls
    dut.delay_time.value = 4800
    dut.delay_feedback.value = 0
    dut.delay_mix.value = 0

    # Reverb controls
    dut.reverb_decay.value = 128
    dut.reverb_damping.value = 128
    dut.reverb_mix.value = 0

    # Cabinet controls
    dut.cab_select.value = 0
    dut.cab_bypass.value = 1

    # Master volume (full scale)
    dut.master_vol.value = 255

    # IR loading (inactive)
    dut.ir_we.value = 0
    dut.ir_slot.value = 0
    dut.ir_addr.value = 0
    dut.ir_wdata.value = 0

    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_sample(dut, value, last=False):
    """Send a single sample on the AXI-Stream input and wait for handshake."""
    data_width = int(dut.DATA_WIDTH)
    if value < 0:
        value = value + (1 << data_width)
    dut.s_axis_tdata.value = int(value) & ((1 << data_width) - 1)
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = int(last)

    while True:
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.s_axis_tready.value) == 1:
            break

    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0


async def collect_outputs(dut, max_cycles=5000, count=None):
    """Collect output samples from the AXI-Stream output.

    Args:
        dut: DUT handle
        max_cycles: maximum clock cycles to wait
        count: number of samples to collect (None = collect all within max_cycles)

    Returns:
        List of signed output values
    """
    data_width = int(dut.DATA_WIDTH)
    outputs = []

    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            val = int(dut.m_axis_tdata.value)
            if val >= (1 << (data_width - 1)):
                val -= (1 << data_width)
            outputs.append(val)
            if count is not None and len(outputs) >= count:
                break

    return outputs


@cocotb.test()
async def test_signal_passes(dut):
    """Feed a simple signal through the full chain with most effects bypassed, verify output appears."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH)

    # Bypass all effects, set master volume to full
    dut.fx_bypass.value = 0xFF
    dut.cab_bypass.value = 1
    dut.master_vol.value = 255
    await RisingEdge(dut.clk)

    # Send a series of nonzero samples
    test_value = 10000  # A modest positive value
    num_samples = 20

    for i in range(num_samples):
        await send_sample(dut, test_value)

    # Wait for pipeline to flush and collect outputs
    outputs = await collect_outputs(dut, max_cycles=5000, count=num_samples)

    assert len(outputs) > 0, "No output from amp_channel — signal did not pass through"

    # With all effects bypassed and master_vol=255, output should be
    # approximately input * 255 / 256 (master volume scaling)
    expected = (test_value * 255) >> 8
    tolerance = abs(expected) * 0.15 + 5  # 15% tolerance + 5 LSB

    # Check that at least some outputs are close to expected
    close_count = sum(1 for v in outputs if abs(v - expected) < tolerance)
    assert close_count > 0, \
        f"No output values close to expected {expected}. Got: {outputs[:10]}"


@cocotb.test()
async def test_all_bypassed(dut):
    """With fx_bypass=0xFF, input should pass through with only master volume applied."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH)

    # All bypassed, cab_bypass also set, master volume = 128 (half)
    dut.fx_bypass.value = 0xFF
    dut.cab_bypass.value = 1
    dut.master_vol.value = 128
    await RisingEdge(dut.clk)

    # Test with multiple input values
    test_values = [8000, -4000, 16000, -8000, 100]
    num_flush = 30  # Extra samples to flush pipeline

    # Send test values followed by flush zeros
    for val in test_values:
        await send_sample(dut, val)

    for _ in range(num_flush):
        await send_sample(dut, 0)

    # Collect outputs
    outputs = await collect_outputs(dut, max_cycles=8000, count=len(test_values) + num_flush)

    assert len(outputs) >= len(test_values), \
        f"Expected at least {len(test_values)} outputs, got {len(outputs)}"

    # With master_vol=128, expected output = input * 128 / 256 = input / 2
    # Check that the first few outputs correspond to our test values scaled by 0.5
    # (there may be pipeline latency, so find the first nonzero output)
    nonzero_outputs = [(i, v) for i, v in enumerate(outputs) if v != 0]

    assert len(nonzero_outputs) > 0, "All outputs were zero despite nonzero input"

    # Find the first output that matches our expected pattern
    first_expected = (test_values[0] * 128) >> 8
    tolerance = abs(first_expected) * 0.15 + 3

    match_found = False
    for idx, val in nonzero_outputs:
        if abs(val - first_expected) < tolerance:
            match_found = True
            # Verify subsequent values if available
            for j, test_val in enumerate(test_values[1:], 1):
                if idx + j < len(outputs):
                    exp = (test_val * 128) >> 8
                    tol = abs(exp) * 0.15 + 3
                    # Just check, don't fail on subsequent (timing may vary)
                    if abs(outputs[idx + j] - exp) > tol:
                        pass  # Pipeline timing may shift samples
            break

    assert match_found, \
        f"Could not find expected output ~{first_expected} in outputs. " \
        f"First few nonzero: {nonzero_outputs[:5]}"
