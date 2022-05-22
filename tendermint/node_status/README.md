# status
This system will alert you with telegram about jails and inactive status. Also it sends you every hour short info about your node status.

Instruction:

1. Google `how to create telegram bot via @FatherBot`. Customize your bot (avatar, description and etc.) and `get bot API token` ([how_to](https://www.siteguarding.com/en/how-to-get-telegram-bot-api-token)).
2. Create at least 2 channels: `alarm` and `log`. Customize them, add your bot into your chats and `get chats IDs` ([how_to](https://stackoverflow.com/questions/32423837/telegram-bot-how-to-get-a-group-chat-id)).
3. Connect to your server and create `status` folder in the `$HOME directory` with `mkdir $HOME/status/`.
4. In this folder you have to create `cosmos.sh` file with `nano $HOME/status/cosmos.sh`. You don't have to do any edits on `cosmos.sh` file, it's ready to use.
> You can find `cosmos.sh` in this repository.
5. Also you have to create as many `cosmos.conf` files with `nano $HOME/status/cosmos.conf`, as many nodes you have on the current server. Customize your config files.
> You can find `cosmos.conf.example` and `curl.example` in this repository.
6. Run `bash cosmos.sh` to check your settings. Normal output:

```
root@v1131623:~/status# bash cosmos.sh 
 
/// 2022-05-21 14:16:44 ///
 
pylons-testnet-3

sync >>> 373010/373010.
jailed > true.
 
/// 2022-05-21 14:16:48 ///
 
stafihub-public-testnet-2

sync >>> 512287/512287.
place >> 47/100.
stake >> 118.12 fis.

root@v1131623:~/status# 
```

7. Create `slash.sh` with `nano $HOME/status/slash.sh`. This bash script will divide group of messages.
> You can find `slash.sh.example` in this repository.
8. Add some rules with `chmod u+x cosmos.sh slash.sh`.
9. Edit crontab with `crontab -e`.
> You can find `crontab.example` in this repository.
10. Check you logs with `cat $HOME/status/cosmos.log` or `tail $HOME/status/cosmos.log -f`.
