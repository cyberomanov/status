import requests

from config import *


class TelegramBot:
    def __init__(self, bot_api_token: str = BOT_API_TOKEN, alarm_chat_id: str = ALARM_CHAT_ID):
        self.bot_api_token = bot_api_token
        self.alarm_chat_id = alarm_chat_id

    def send_message(self, message: str):
        requests.post(
            f"https://api.telegram.org/bot{self.bot_api_token}/sendMessage",
            json={
                'chat_id': self.alarm_chat_id,
                'text': message
            }
        )
