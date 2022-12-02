# status
This system will alert you with telegram about active/activating/deactivating stake, deliquent status available percent validators visible in gossip and other. Also it sends you every hour short info about your node status.

Instruction:

1. Create telegram bot via `@BotFather`, customize it and `get bot API token` ([how_to](https://www.siteguarding.com/en/how-to-get-telegram-bot-api-token)).
2. Create at least 2 groups: `alarm` and `log`. Customize them, add your bot into your chats and `get chats IDs` ([how_to](https://stackoverflow.com/questions/32423837/telegram-bot-how-to-get-a-group-chat-id)).
3. Connect to your server and create `status` folder in the `$HOME directory` with `mkdir $HOME/status/`.
4. In this folder, `$HOME/status/`, you have to create `solana.sh` file with `nano $HOME/status/solana.sh`. You don't have to do any edits on `solana.sh` file, it's ready to use.
> You can find `solana.sh` in this repository.
5. In this folder, `$HOME/status/`, you have to create `solana.conf` file with `nano $HOME/status/solana.conf`. Customize it.
> You can find `solana.conf` in this repository.
6. Install some packages with `sudo apt-get install jq sysstat bc -y`.
7. Run `bash solana.sh` to check your settings. Normal output:

```
/// 2022-12-03 00:05:47 ///
 
mainnet >>>> #380.

progress >>> 85.50%.
skiprate >>> 3.94%.

time_left >> 6h 57m 27s.
appr_time >> Dec 03, 07:03.

cyberomanov-m

bin_version >>> 1.13.4.

skip is higher than average: 8.00 > 3.94.

passed/total >> 100/112 | 89.28%.
exec/skipped >>    92/8 | 8.00%.
vote_credits >>  321515 | #1786.

active_stake >> 78482.11.

id_balance >>>> 1.82.
vote_balance >> 8.59.
```

9. Add some rules with `chmod u+x $HOME/status/solana.sh`.
10. Edit crontab with `crontab -e`.
> You can find `crontab` in this repository.
11. Check your logs with `cat $HOME/status/solana.log` or `tail $HOME/status/solana.log -f`.
