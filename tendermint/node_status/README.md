# status
This system will alert you with telegram about jails and inactive status. Also it sends you every hour short info about your node status.

Instruction:

1. Create telegram bot via `@BotFather`, customize it and `get bot API token` ([how_to](https://www.siteguarding.com/en/how-to-get-telegram-bot-api-token)).
2. Create at least 2 groups: `alarm` and `log`. Customize them, add your bot into your chats and `get chats IDs` ([how_to](https://stackoverflow.com/questions/32423837/telegram-bot-how-to-get-a-group-chat-id)).
3. Connect to your server and create `status` folder in the `$HOME directory` with `mkdir $HOME/status/`.
4. In this folder, `$HOME/status/`, you have to create `cosmos.sh` file with `nano $HOME/status/cosmos.sh`. You don't have to do any edits on `cosmos.sh` file, it's ready to use.
> You can find `cosmos.sh` in this repository.
5. In this folder, `$HOME/status/`, you have to create `cosmos.conf` file with `nano $HOME/status/cosmos.conf`. Customize it.
> You can find `cosmos.conf` in this repository.
6. Also you have to create as many `name.conf` files with `nano $HOME/status/name.conf`, as many nodes you have on the current server. Customize your config files. For ex: I have agoric, gravity and sifchain on the same server, so I have to create 3 files: `agoric.conf`, `gravity.conf` and `sifchain.conf`.
> You can find `name.conf` and `curl.md` in this repository.
7. Install some packages with `sudo apt-get install jq sysstat bc smartmontools fdisk -y`.
8. Run `bash cosmos.sh` to check your settings. Normal output:
```
root@v1131623:~/status# bash cosmos.sh
 
/// 2022-07-09 11:42:37 ///
 
testnets  |  load

cpu >>>>> 68%.
ram >>>>> 47%.
part >>>> 55%.
load >>>> 14.03.
 
dws-t  |  cyberomanov

exp/me >> 955540/955540.
place >>> 88/200.
stake >>> 34.98 dws.

root@v1131623:~/status#
```
9. Add some rules with `chmod u+x $HOME/status/cosmos.sh`.
10. Edit crontab with `crontab -e`.
> You can find `crontab` in this repository.
11. Check your logs with `cat $HOME/status/cosmos.log` or `tail $HOME/status/cosmos.log -f`.
