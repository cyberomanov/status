import time

from config import *
from sdk.logger import Logger
from sdk.server import Server
from sdk.telegram import TelegramBot


def ping_servers():
    for server in SERVERS:
        ip = SERVERS[server]
        instance = Server(ip=ip)
        if not instance.is_server_online():
            log.add_warn_record(f"[{server}] with [{ip}] is offline.")
            telegram.send_message(message=f"[{server}] with [{ip}] is offline.")
        else:
            log.add_info_record(f"[{server}] with [{ip}] is online.")
    time.sleep(TIME_SLEEP_BETWEEN_PINGS_SEC)


if __name__ == '__main__':
    log = Logger()
    telegram = TelegramBot()

    while True:
        try:
            ping_servers()
        except Exception as e:
            log.add_exception_record(e)
