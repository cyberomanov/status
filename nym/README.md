# status
This system will alert you with telegram about outdated and inactive status. Also it sends you every hour short info about your node status.

Instruction:

1. Google `how to create telegram bot via @FatherBot`. Customize your bot (avatar, description and etc.) and `get bot API token`.
2. Create at least 2 channels: `alarm` and `log`. Customize them and `get chats IDs`.
3. Connect to your server and create `status` folder in the `$HOME directory` with `mkdir $HOME/status/`.
4. In this folder you have to create `nym.sh` file with `nano $HOME/status/nym.sh`. You don't have to do any edits on `nym.sh` file, it's ready to use.
> You can find `nym.sh` in this repository.
5. Also you have to create as many `nym.conf` files with `nano $HOME/status/nym.conf`, as many nodes you have on the current server. Customize your config files.
> You can find `nym.conf.example` in this repository.
6. Run `bash nym.sh` to check your settings. Normal output:

```
root@ubuntu:~/status# bash nym.sh
 
/// 2022-05-21 20:07:32 ///
 
nym | cyberomanov

stake >>>>> 24986.90 nym.
uptime >>>> 100%/h, 99%/d.
estimated > 0.0179 nym per hour.
rewards >>> 19.10 nym.

root@ubuntu:~/status# 
```

7. Create `slash.sh` with `nano $HOME/status/slash.sh`, if you don't have one yet. This bash script will divide group of messages.
> You can find `slash.sh.example` in this repository.
8. Add some rules with `chmod u+x nym.sh slash.sh`.
9. Edit crontab with `crontab -e`.
> You can find `crontab.example` in this repository.
10. Check you logs with `cat $HOME/status/nym.log` or `tail $HOME/status/nym.log -f`.
