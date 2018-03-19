require "discordrb"
require "twitter"
require "json"

INFO = {
  client: 335321103834677250,
  server: 279258603976785921,
  channel: 424231864891473922
}

TOKEN = open(".discord",&:read).strip
bot = Discordrb::Bot.new(token: TOKEN, client_id: INFO[:client])
at_exit{bot.run}

$twitter = Twitter::REST::Client.new do |config|
  config.consumer_key, config.consumer_secret, config.access_token, config.access_token_secret = open(".twitter",&:read).split(?\n)
end

$sentence = []

def tweet
  status = $sentence.join(" ")
  p status
  $twitter.update(status)
  $sentence = []
end

bot.ready {
  bot.on
  CHANNEL = bot.servers[INFO[:server]].channels.select{|i|i.id==INFO[:channel]}.first
  loop{
    x = gets
    if x != nil && x.chomp.strip != ""
      $sentence << x.chomp
      puts "Added '#{$sentence[-1]}' to the sentence"
    end
  }
}

bot.message(in:INFO[:channel]) { |e|
  puts "[MESSAGE] '#{e.message}'"
  msg = e.message.to_s.strip
  unless msg.match(%r{^(?<esc>[\*\_]).+\k<esc>$})

    if msg.match(/[\.,?!]$/)
      $sentence[-1] << msg
      puts "$sentence[-1] << msg"

      if msg.match(/[\.?!]$/)
        puts "Sentence finished, tweeting..."
        CHANNEL.send_message("*(Sentence finished, tweeting...)*")
        tweet
        puts "Done."
        CHANNEL.send_message("*(Done.)*")
      end

    else

      $sentence << msg
      puts "$sentence << msg"

    end

  else
    puts "Message was a comment, skipping."
  end
}
