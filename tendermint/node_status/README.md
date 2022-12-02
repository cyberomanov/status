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
6. Also you have to create as many `NAME.conf` files with `nano $HOME/status/NAME.conf`, as many nodes you have on the current server. Customize your config files.
> You can find `pylons.conf` and `curl.md` in this repository.
7. Install some packages with `sudo apt-get install jq sysstat bc -y`.
8. Run `bash cosmos.sh` to check your settings. Normal output:

```
┌-------------------------------------┐
   2022-12-02 | 19:37:02 | i1 | load   
└-------------------------------------┘

cpu_used >>>>> 55%.
ram_used >>>>> 19%.
swap_used >>>> 19%.
part_used >>>> 41%.
nvme0n1 >>>>>> 100% spare, 43% used.
server_load >> 24.02.

┌--------------------------┐
   kyve-b  |  cyberomanov   
└--------------------------┘

node >>>>>>>>> connectable.
exp/me >>>>>>> 1245736/1245736, gap: 0 blocks.
chain >>>>>>>> alive, consensus: 0.00.
block_time >>> 5.65 sec.
validator >>>> exists.
priv_key >>>>> right.
status >>>>>>> active.
place >>>>>>>> 52/100.
token_price >> $n/a.
apr >>>>>>>>>> 1293.45%.
stake >>>>>>>> 12851.10 kyve.
balance >>>>>> 5286.48 kyve.
outstanding >> 12630.50 kyve.
salary/mo >>>> 13851.90 kyve.
missed >>>>>>> 0 blocks, 0 in a row.
jailed >>>>>>> after 50 missed blocks.
gov >>>>>>>>>> no unvoted proposals.
upgrade >>>>>> no upgrade scheduled.
```

9. Add some rules with `chmod u+x $HOME/status/cosmos.sh`.
10. Edit crontab with `crontab -e`.
> You can find `crontab` in this repository.
11. Check your logs with `cat $HOME/status/cosmos.log` or `tail $HOME/status/cosmos.log -f`.
