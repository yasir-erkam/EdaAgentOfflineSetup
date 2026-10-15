"""Deny external socket connections and DNS while exercising the actual launcher."""
import ipaddress
import os
from pathlib import Path
import runpy
import sys

launcher = Path(sys.argv[1])
log_path = Path(os.environ["EDA_PROBE_NETWORK_LOG"])


def network_guard(event, args):
    if event == "socket.getaddrinfo":
        host = args[0]
    elif event == "socket.connect":
        address = args[1]
        host = address[0] if isinstance(address, tuple) else None
    else:
        return
    if host is None or host == "localhost":
        return
    try:
        if ipaddress.ip_address(host).is_loopback:
            return
    except ValueError:
        pass
    with log_path.open("a", encoding="utf-8") as log:
        log.write(f"{event}: {host}\n")
    raise OSError("External network is disabled by the offline integration test")


sys.addaudithook(network_guard)
sys.argv = [str(launcher)]
runpy.run_path(str(launcher), run_name="__main__")
