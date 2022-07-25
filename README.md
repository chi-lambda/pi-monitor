# Pi Monitor

Monitors internet connection and Raspberry Pi runtime data and provides an interface with Telegram.

## Installation

1. Create a bot with Telegram's BotFather.
2. Start a conversation with the bot.
3. Get the chat_id of that conversation.
4. Replace the values in `config.exs.example` and rename it to `config.secret.exs`.

## Commands

* `/ping` Gets the current ping states of the last 60 minutes
* `/ip` Returns the external IP address as reported by https://ip4.me/api/.
* `/temp` returns the current temperature from /sys/class/thermal/thermal_zone0/temp
