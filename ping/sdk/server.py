import os
import subprocess


class Server:
    PING_TRIES = 5

    def __init__(self, ip: str):
        self.ip = ip

    def _is_server_online(self) -> bool:
        with open(os.devnull, 'w') as DEVNULL:
            try:
                subprocess.check_call(
                    ['ping', '-c', '1', f'{self.ip}'],
                    stdout=DEVNULL,
                    stderr=DEVNULL
                )
                return True
            except subprocess.CalledProcessError:
                return False

    def is_server_online(self) -> bool:
        if not self._is_server_online():
            offline_ping = 1
            for i in range(1, Server.PING_TRIES):
                offline_ping += 1 if not self._is_server_online() else 0
            return False if offline_ping == Server.PING_TRIES else True
        else:
            return True
