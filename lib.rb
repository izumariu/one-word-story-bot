require "discordrb"
require "twitter"
require "json"

INFO = {
  client: 335321103834677250,
  server: 279258603976785921,
  channel: 424231864891473922
}

TOKEN = open(".discord",&:read).strip
$bot = Discordrb::Bot.new(token: TOKEN, client_id: INFO[:client])

$bot.ready{$bot.game=""}

$0=="irb" || at_exit{$bot.run}
