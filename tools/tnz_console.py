# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""IBM tnz console with explicit compatibility for archived EMAS SBA orders."""

import time

from tnz.tnz import Tnz


class EmasTerminal(Tnz):
    def __init__(self, legacy_12bit=False):
        super().__init__()
        self.terminal_type = "IBM-3278-2"
        self.use_tn3270e = False
        self.legacy_12bit = legacy_12bit
        self.raw_address_seen = False

    def address(self, encoded):
        if self.legacy_12bit:
            return ((encoded[0] & 63) << 6) | (encoded[1] & 63)
        return super().address(encoded)

    def _process_order_0x11(self, order, start, stop, zti=None):
        if self.legacy_12bit and not order[start + 1] & 0xC0:
            self.raw_address_seen = True
        return super()._process_order_0x11(order, start, stop, zti=zti)

    def _process_w(self, data, start, stop, pid=0, zti=None):
        # Hercules adds a canonical SBA to chained Writes using its modern
        # address decoding. tnz already retained the previous raw position.
        if (
            self.legacy_12bit
            and self.raw_address_seen
            and stop - start >= 5
            and data[start + 2] == 0x11
            and data[start + 3] & 0xC0
        ):
            data = (
                data[: start + 3] + self.address_bytes(self.bufadd) + data[start + 5 :]
            )
        return super()._process_w(data, start, stop, pid=pid, zti=zti)


class Console:
    def __init__(self, host="127.0.0.1", port=3271, legacy_12bit=False):
        self.terminal = EmasTerminal(legacy_12bit)
        try:
            self.terminal.connect(host, port)
            self.terminal.wait(0.05)
            if self.terminal.seslost:
                failure = self.terminal.seslost
                if isinstance(failure, tuple):
                    raise failure[1]
                raise ConnectionError("tnz connection failed")
        except BaseException:
            self.close()
            raise

    def receive(self, seconds=2):
        deadline = time.monotonic() + seconds
        while (remaining := deadline - time.monotonic()) > 0:
            self.terminal.wait(remaining)
            if self.terminal.seslost:
                raise ConnectionError(f"tnz session lost: {self.terminal.seslost}")

    def enter(self, text):
        self.terminal.key_home()
        self.terminal.key_eraseeof()
        count = self.terminal.key_data(text)
        if count != len(text):
            raise ValueError(f"console accepted {count} of {len(text)} characters")
        self.terminal.key_aid(0x7D)

    def text(self):
        t = self.terminal
        return "\n".join(
            t.scrstr(row * t.maxcol, (row + 1) * t.maxcol).rstrip()
            for row in range(t.maxrow)
        )

    def close(self):
        try:
            self.terminal.shutdown()
        finally:
            self.terminal.close()
