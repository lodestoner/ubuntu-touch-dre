import importlib.util
import struct
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "tools" / "dre-boot-hardware.py"
spec = importlib.util.spec_from_file_location("dre_boot_hardware", SCRIPT)
hardware = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hardware)


class BootHardwareTests(unittest.TestCase):
    def test_repairs_only_zero_range_axes(self):
        ranges = {
            hardware.ABS_MT_WIDTH_MAJOR: [7, 0, 0, 0, 0, 0],
            hardware.ABS_MT_PRESSURE: [4, 0, 200, 0, 0, 0],
        }
        writes = []

        def ioctl(_device, request, data, _mutate=False):
            axis = request & 0x3F
            if request & 0x80000000:
                data[:] = struct.pack("6i", *ranges[axis])
            else:
                ranges[axis] = list(struct.unpack("6i", data))
                writes.append(axis)

        hardware.repair_touch_axes(1, ioctl)

        self.assertEqual(writes, [hardware.ABS_MT_WIDTH_MAJOR])
        self.assertEqual(ranges[hardware.ABS_MT_WIDTH_MAJOR], [7, 0, 255, 0, 0, 0])
        self.assertEqual(ranges[hardware.ABS_MT_PRESSURE][2], 200)

    def test_finds_touchpanel_by_name_not_event_number(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for event, name in [("event1", "gpio-keys"), ("event5", "touchpanel")]:
                device = root / event / "device"
                device.mkdir(parents=True)
                (device / "name").write_text(name + "\n")

            self.assertEqual(hardware.find_touch_event(root), "event5")


if __name__ == "__main__":
    unittest.main()
