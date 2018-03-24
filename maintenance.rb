load "lib.rb"

$bot.ready {
  $bot.game = "MAINTENANCE"
  at_exit{$bot.game=""}
}
