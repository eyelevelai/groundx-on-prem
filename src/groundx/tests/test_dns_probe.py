import importlib.util
import pathlib
import socket
import struct
import threading
import time
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "files" / "dns_probe.py"
spec = importlib.util.spec_from_file_location("dns_probe", SCRIPT)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class DNSProbeTests(unittest.TestCase):
    def test_normal_resolution_never_reads_endpoint_slices(self):
        result = probe.check("redis.example.test", 0.05,
                             resolver=lambda *_: [(socket.AF_INET, 0, 0, "", ("127.0.0.1", 0))],
                             list_endpoints=lambda: self.fail("EndpointSlices must not be read"))
        self.assertEqual(result["outcome"], "resolved")

    def test_slow_resolution_checks_each_endpoint(self):
        def slow_resolver(*_):
            time.sleep(0.01)
            return [(socket.AF_INET, 0, 0, "", ("127.0.0.1", 0))]
        result = probe.check("redis.example.test", 0.05, slow_threshold=0.001,
                             resolver=slow_resolver,
                             list_endpoints=lambda: [{"address": "10.1.0.8", "ready": True}],
                             query=lambda *_: {"outcome": "timeout"})
        self.assertEqual(result["outcome"], "slow")
        self.assertEqual(result["endpoints"][0]["direct"]["outcome"], "timeout")

    def test_ready_but_silent_backend_is_visible(self):
        answering = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        answering.bind(("127.0.0.1", 0))
        silent = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        silent.bind(("127.0.0.1", 0))
        def respond():
            packet, peer = answering.recvfrom(4096)
            reply = packet[:2] + struct.pack("!HHHHH", 0x8180, 1, 1, 0, 0) + packet[12:]
            answering.sendto(reply, peer)
        thread = threading.Thread(target=respond, daemon=True)
        thread.start()
        ports = {"answering": answering.getsockname()[1], "silent": silent.getsockname()[1]}
        items = [{"address": name, "ready": True} for name in ports]
        def failed_resolver(*_):
            raise socket.gaierror(socket.EAI_AGAIN, "Temporary failure in name resolution")
        try:
            result = probe.check("redis.example.test", 0.05, resolver=failed_resolver,
                                 list_endpoints=lambda: items,
                                 query=lambda address, host, timeout: probe.direct_query(
                                     "127.0.0.1", host, timeout, port=ports[address]))
        finally:
            answering.close()
            silent.close()
            thread.join(timeout=1)
        self.assertEqual(result["outcome"], "failed")
        self.assertEqual(result["endpoints"][0]["direct"]["outcome"], "answered")
        self.assertEqual(result["endpoints"][1]["direct"]["outcome"], "timeout")
        self.assertTrue(all(item["ready"] for item in result["endpoints"]))

    def test_endpoint_slice_identity_and_readiness(self):
        payload = {"items": [{"endpoints": [{"addresses": ["10.1.0.8"],
                     "targetRef": {"name": "coredns-a"}, "nodeName": "node-a",
                     "conditions": {"ready": False, "serving": True}}]}]}
        self.assertEqual(probe.parse_endpoints(payload), [{"address": "10.1.0.8",
                         "pod": "coredns-a", "node": "node-a", "ready": False, "serving": True}])


if __name__ == "__main__":
    unittest.main()
