"""AXI-Stream bus monitor for cocotb testbenches."""

import cocotb
from cocotb.triggers import RisingEdge, ReadOnly
import random


class AxisMonitor:
    """Monitors data from an AXI-Stream master interface.

    Args:
        dut: cocotb DUT handle
        prefix: signal name prefix (e.g., 'm_axis' for m_axis_tdata, etc.)
        clock: clock signal
        data_width: bit width of tdata for sign extension
    """

    def __init__(self, dut, prefix, clock, data_width=24):
        self.dut = dut
        self.clock = clock
        self.data_width = data_width

        self.tdata = getattr(dut, f"{prefix}_tdata")
        self.tvalid = getattr(dut, f"{prefix}_tvalid")
        self.tlast = getattr(dut, f"{prefix}_tlast")
        self.tready = getattr(dut, f"{prefix}_tready", None)

    async def set_ready(self, ready=True):
        """Set the tready signal (if we control it)."""
        if self.tready is not None:
            self.tready.value = int(ready)

    async def receive(self, count=None, timeout_cycles=10000):
        """Receive data beats from the AXI-Stream interface.

        Args:
            count: number of beats to receive (None = receive until tlast)
            timeout_cycles: maximum clock cycles to wait

        Returns:
            List of received integer values (unsigned representation)
        """
        data = []
        cycles = 0

        if self.tready is not None:
            self.tready.value = 1

        while cycles < timeout_cycles:
            await RisingEdge(self.clock)
            await ReadOnly()
            cycles += 1

            if int(self.tvalid.value) == 1:
                ready = True
                if self.tready is not None:
                    ready = int(self.tready.value) == 1

                if ready:
                    val = int(self.tdata.value)
                    data.append(val)

                    if count is not None and len(data) >= count:
                        break
                    if count is None and int(self.tlast.value) == 1:
                        break

        return data

    async def receive_with_backpressure(self, count=None, timeout_cycles=10000,
                                         stall_probability=0.3):
        """Receive data with random backpressure (tready toggling).

        Args:
            count: number of beats to receive (None = until tlast)
            timeout_cycles: max wait
            stall_probability: probability of deasserting tready each cycle

        Returns:
            List of received integer values
        """
        data = []
        cycles = 0

        while cycles < timeout_cycles:
            # Randomly assert/deassert ready
            if self.tready is not None:
                self.tready.value = int(random.random() >= stall_probability)

            await RisingEdge(self.clock)
            await ReadOnly()
            cycles += 1

            ready = True
            if self.tready is not None:
                ready = int(self.tready.value) == 1

            if int(self.tvalid.value) == 1 and ready:
                val = int(self.tdata.value)
                data.append(val)

                if count is not None and len(data) >= count:
                    break
                if count is None and int(self.tlast.value) == 1:
                    break

        # Leave ready asserted
        if self.tready is not None:
            self.tready.value = 1

        return data
