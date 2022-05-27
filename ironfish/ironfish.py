import requests
from datetime import datetime

# set variables, don't touch anything except this 3 things
telegram_bot_api = "xxx:xxx-xxx_xxx"
telegram_chat_id = "-228"
urls = ["https://api.ironfish.network/users/1",
        "https://api.ironfish.network/users/2",
        "https://api.ironfish.network/users/3",
        "https://api.ironfish.network/users/4"
        ]

if __name__ == "__main__":

    # get current time and print it
    time = datetime.now().strftime("%d-%m-%Y %H:%M:%S")
    print(f"/// {time} ///\n")
    print("ironfish\n")

    # graffiti and points max length
    graffiti_max = 0
    points_max = 0

    # create dict
    url_dict = dict.fromkeys(urls)

    # run loop with links
    for url in urls:

        # get account info
        account_info = requests.get(url).json()

        # save values
        graffiti = account_info["graffiti"]
        points = account_info["total_points"]
        rank = account_info["rank"]

        # add account info into the dict
        url_dict[url] = {
            "graffiti": graffiti,
            "total_points": points,
            "rank": rank
        }

        # get the longest graffiti and points
        if len(graffiti) > graffiti_max:
            graffiti_max = len(graffiti)

        if len(str(points)) > points_max:
            points_max = len(str(points))

    # start to collect telegram message
    text = "<b>ironfish</b><code>\n\n"

    # run loop with links
    for url in urls:

        # create pretty output
        graffiti_out = (url_dict[url]["graffiti"] + ' ').ljust(graffiti_max + 2, '>')
        points_out = str(url_dict[url]["total_points"]).rjust(points_max)
        rank_out = url_dict[url]["rank"]

        print(f"{graffiti_out} {points_out} points, #{rank_out}.")
        text = text + f"{graffiti_out} {points_out} points, %23{rank_out}.\n"

    # end the message
    text = text + "</code>"
    print()

    # send message with telegram bot
    telegram = f'https://api.telegram.org/bot{telegram_bot_api}/sendMessage?chat_id={telegram_chat_id}&parse_mode=html&text={text}'
    message = requests.get(telegram)
