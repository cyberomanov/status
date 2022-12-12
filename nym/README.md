# status
This system will alert you with telegram about outdated and inactive status. Also it sends you every hour short info about your node status.

Instruction:

1. Create telegram bot via `@BotFather`, customize it and `get bot API token` ([how_to](https://www.siteguarding.com/en/how-to-get-telegram-bot-api-token)).
2. Create at least 2 groups: `alarm` and `log`. Customize them, add your bot into your chats and `get chats IDs` ([how_to](https://stackoverflow.com/questions/32423837/telegram-bot-how-to-get-a-group-chat-id)).
3. Connect to your server and create `status` folder in the `$HOME` directory with `mkdir $HOME/status/`.
4. In this folder you have to create `nym.sh` file with `nano $HOME/status/nym.sh`. You don't have to do any edits on `nym.sh` file, it's ready to use.
> You can find `nym.sh` in this repository.
5. Also you have to create as many `nym.conf` files with `nano $HOME/status/nym.conf`, as many nodes you have on the current server. Customize your config files.
> You can find `nym.conf.example` in this repository.
6. Install `jq` and `bc` packages with `sudo apt-get install jq bc -y`.
7. Run `bash nym.sh` to check your settings. Normal output:

```
root@ubuntu:~/status# bash nym.sh
 
/// 2022-12-12 10:57:38 ///
 
nym-m  |  cyberomanov

hour/day >> 100%/99%.
version >>> actual.
status >>>> active.
stake >>>>> 192431.19 | $31795.41.
salary/m >>    345.60 | $57.10.
unpaid >>>>    295.49 | $48.82.
balance >>>    215.69 | $35.64.

root@ubuntu:~/status# 
```

8. Create `slash.sh` with `nano $HOME/status/slash.sh`, if you don't have one yet. This bash script will divide group of messages.
> You can find `slash.sh.example` in this repository.
9. Add some rules with `chmod u+x nym.sh slash.sh`.
10. Edit crontab with `crontab -e`.
> You can find `crontab.example` in this repository.
11. Check your logs with `cat $HOME/status/nym.log` or `tail $HOME/status/nym.log -f`.
