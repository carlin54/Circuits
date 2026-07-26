"""AXI-Stream bus driver for cocotb testbenches."""

import cocotb
from cocotb.triggers import RisingEdge, ReadOnly
import random


class AxisDriver:
    """Drives data onto an AXI-Stream slave interface.

    Args:
        dut: cocotb DUT handle
        prefix: signal name prefix (e.g., 's_axis' for s_axis_tdata, etc.)
        clock: clock signal
        random_ready: if True, randomly deassert tready for backpressure testing
    """

    def __init__(self, dut, prefix, clock, random_ready=False):
        self.dut = dut
        self.clock = clock
        self.random_ready = random_ready

        self.tdata = getattr(dut, f"{prefix}_tdata")
        self.tvalid = getattr(dut, f"{prefix}_tvalid")
        self.tlast = getattr(dut, f"{prefix}_tlast")

        # tready is an output from the DUT when we're driving the slave side
        self.tready = getattr(dut, f"{prefix}_tready", None)

    async def reset(self):
        """Deassert all driven signals."""
        self.tdata.value = 0
        self.tvalid.value = 0
        self.tlast.value = 0

    async def send(self, data, last_flags=None):
        """Send a list of data values over AXI-Stream.

        Args:
            data: list of integer values to send
            last_flags: optional list of booleans for tlast per beat.
                       If None, tlast is asserted only on the final beat.
        """
        for i, val in enumerate(data):
            self.tdata.value = int(val)
            self.tvalid.value = 1

            if last_flags is not None:
                self.tlast.value = int(last_flags[i])
            else:
                self.tlast.value = int(i == len(data) - 1)

            while True:
                await RisingEdge(self.clock)
                await ReadOnly()
                if self.tready is None or int(self.tready.value) == 1:
                    break

        # Deassert valid after frame
        self.tvalid.value = 0
        self.tlast.value = 0
        self.tdata.value = 0

    async def send_with_gaps(self, data, gap_probability=0.3, last_flags=None):
        """Send data with random gaps (tvalid deasserted) between beats."""
        for i, val in enumerate(data):
            # Random gap
            while random.random() < gap_probability:
                self.tvalid.value = 0
                await RisingEdge(self.clock)

            self.tdata.value = int(val)
            self.tvalid.value = 1

            if last_flags is not None:
                self.tlast.value = int(last_flags[i])
            else:
                self.tlast.value = int(i == len(data) - 1)

            while True:
                await RisingEdge(self.clock)
                await ReadOnly()
                if self.tready is None or int(self.tready.value) == 1:
                    break

        self.tvalid.value = 0
        self.tlast.value = 0
        self.tdata.value = 0
