# status
Status &amp; alarm log with bash and telegram bot.

Instruction:

1. Google 'how to create telegram bot via @FatherBot'. Customize your bot (avatar, description and etc.) and **get bot token**.
2. Create at least 2 channels: **alarm** and **log**. Customize them and **get chats IDs**.
3. Connect to your server and create **status** folder in $HOME directory.
4. In this folder you have to create **main.sh** file, which can be find in **status_ex** folder. You don't have to edit this file, it's ready to use.
5. Also you have to create as many **cosmos.conf** files, as many you have on the current server. Customize your config files.
6. Run `bash main.sh`.
