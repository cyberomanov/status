# status
This system will alert you with telegram about ironfish account points and rank every hour.

Instruction:

1. Create telegram bot via `@BotFather`, customize it and `get bot API token` ([how_to](https://www.siteguarding.com/en/how-to-get-telegram-bot-api-token)).
2. Create a group, for example: `ironfish`. Customize it, add your bot into your chat and `get chat ID` ([how_to](https://stackoverflow.com/questions/32423837/telegram-bot-how-to-get-a-group-chat-id)).
3. Connect to your server and create `status` folder in the `$HOME directory` with `mkdir $HOME/status/`.
4. In this folder you have to create `ironfish.py` file with `nano $HOME/status/ironfish.py` and set following variables: `telegram_bot_api`, `telegram_chat_id` and `urls`.
> You can find `ironfish.py` in this repository.
5. Install `python3`, `pip`, if you don't have them yet and run `pip install requests datetime` ([how_to](https://www.makeuseof.com/install-python-ubuntu/)).
6. Run `python3 ironfish.py` to check your settings. Normal output:

```
root@cyberomanov:~# python3 ironfish.py

/// 27-05-2022 06:44:12 ///

ironfish

cyberomanov >>>> 658 points, #654.
cyberpunk >>>>>> 129 points, #913.
cyberG >>>>>>>>>  11 points, #12099.

root@cyberomanov:~# 
```
7. Check your telegram, message must be arrived.
8. Edit crontab with `crontab -e`. Example where I get message every 3rd minute of an hour.
```
3 */1 * * * python3 $HOME/status/ironfish.py >> $HOME/status/ironfish.log
```
9. Check your logs with `cat $HOME/status/ironfish.log` or `tail $HOME/status/ironfish.log -f`.
