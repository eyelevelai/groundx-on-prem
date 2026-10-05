"""Report resolver failures from extraction nodes and test each CoreDNS endpoint."""

import json
import os
import random
import socket
import ssl
import struct
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone


def endpoints():
    host = os.environ["KUBERNETES_SERVICE_HOST"]
    port = os.environ.get("KUBERNETES_SERVICE_PORT", "443")
    query = urllib.parse.urlencode({"labelSelector": "kubernetes.io/service-name=kube-dns"})
    url = f"https://{host}:{port}/apis/discovery.k8s.io/v1/namespaces/kube-system/endpointslices?{query}"
    token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    ca_path = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    with open(token_path, encoding="utf-8") as token_file:
        token = token_file.read().strip()
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    context = ssl.create_default_context(cafile=ca_path)
    with urllib.request.urlopen(request, context=context, timeout=3) as response:
        payload = json.load(response)
    return parse_endpoints(payload)


def parse_endpoints(payload):
    found = []
    for item in payload["items"]:
        for endpoint in item.get("endpoints", []):
            for address in endpoint.get("addresses", []):
                found.append({
                    "address": address,
                    "pod": endpoint.get("targetRef", {}).get("name"),
                    "node": endpoint.get("nodeName"),
                    "ready": endpoint.get("conditions", {}).get("ready"),
                    "serving": endpoint.get("conditions", {}).get("serving"),
                })
    return found


def direct_query(address, hostname, timeout, port=53):
    identifier = random.randrange(65536)
    labels = hostname.rstrip(".").split(".")
    question = b"".join(bytes([len(label)]) + label.encode("ascii") for label in labels) + b"\x00"
    packet = struct.pack("!HHHHHH", identifier, 0x0100, 1, 0, 0, 0) + question + struct.pack("!HH", 1, 1)
    family = socket.AF_INET6 if ":" in address else socket.AF_INET
    started = time.monotonic()
    try:
        with socket.socket(family, socket.SOCK_DGRAM) as connection:
            connection.settimeout(timeout)
            connection.sendto(packet, (address, port))
            response, _ = connection.recvfrom(4096)
        if len(response) < 12:
            return {"outcome": "short_response"}
        reply_id, flags, _, answer_count, _, _ = struct.unpack("!HHHHHH", response[:12])
        if reply_id != identifier or not flags & 0x8000:
            return {"outcome": "invalid_response"}
        return {"outcome": "answered", "rcode": flags & 0xF, "answers": answer_count,
                "duration_ms": round((time.monotonic() - started) * 1000)}
    except socket.timeout:
        return {"outcome": "timeout", "duration_ms": round((time.monotonic() - started) * 1000)}
    except OSError as error:
        return {"outcome": "error", "error": str(error)}


def check(hostname, timeout, slow_threshold=2, resolver=socket.getaddrinfo,
          list_endpoints=endpoints, query=direct_query):
    started = time.monotonic()
    try:
        resolver(hostname, None)
        duration_ms = round((time.monotonic() - started) * 1000)
        if duration_ms < slow_threshold * 1000:
            return {"outcome": "resolved", "duration_ms": duration_ms}
        result = {"outcome": "slow", "duration_ms": duration_ms}
    except OSError as error:
        result = {"outcome": "failed", "duration_ms": round((time.monotonic() - started) * 1000),
                  "resolver_error": str(error)}
    try:
        result["endpoints"] = [{**endpoint, "direct": query(endpoint["address"], hostname, timeout)}
                               for endpoint in list_endpoints()]
    except (OSError, ValueError, KeyError) as error:
        result["endpoints_error"] = str(error)
    return result


def emit(event):
    print(json.dumps({"time": datetime.now(timezone.utc).isoformat(),
                      "node": os.environ.get("NODE_NAME"), "pod": os.environ.get("POD_NAME"),
                      "target": os.environ["TARGET_HOST"], **event}), flush=True)


def main():
    hostname = os.environ["TARGET_HOST"].strip()
    if not hostname or "://" in hostname or "/" in hostname:
        raise ValueError("TARGET_HOST must be a hostname without a scheme or path")
    interval = int(os.environ.get("INTERVAL_SECONDS", "10"))
    success_log_every = int(os.environ.get("SUCCESS_LOG_EVERY", "6"))
    timeout = float(os.environ.get("QUERY_TIMEOUT_SECONDS", "2"))
    slow_threshold = float(os.environ.get("SLOW_THRESHOLD_SECONDS", "2"))
    if min(interval, success_log_every, timeout, slow_threshold) <= 0:
        raise ValueError("interval, summary frequency, timeout, and slow threshold must be positive")
    emit({"outcome": "started", "nameservers": [line.split()[1] for line in open("/etc/resolv.conf", encoding="utf-8")
                                           if line.startswith("nameserver ")]})
    successes = 0
    while True:
        result = check(hostname, timeout, slow_threshold)
        if result["outcome"] == "resolved":
            successes += 1
            if successes >= success_log_every:
                emit({"outcome": "resolved", "checks": successes, "duration_ms": result["duration_ms"]})
                successes = 0
        else:
            emit(result)
            successes = 0
        time.sleep(interval)


if __name__ == "__main__":
    main()
