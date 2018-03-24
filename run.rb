load "lib.rb"


$twitter = Twitter::REST::Client.new do |config|
  config.consumer_key, config.consumer_secret, config.access_token, config.access_token_secret = open(".twitter",&:read).split(?\n)
end

$sentence = []

def tweet
  status = $sentence.join(" ")
  p status
  $sentence = []
  $twitter.update(status)
end

module Message
  COMMENT = 0
  WORD = 1
  PUNCTUATION = 2
  EOS = 4
end

def flag_set?(flags, flag) ; flags & flag == flag ; end
def set_flag(flags, flag) ; flags | flag ; end
def unset_flag(flags, flag) ; flags ^ flag ; end

def eval_message(msg)
  flags = Message::WORD | Message::PUNCTUATION | Message::EOS
  if !msg.match(%r{^(?<esc>[\*\_]).+\k<esc>$})
    puts "!msg.match(%r{^(?<esc>[\*\_]).+\k<esc>$}) == true"
    if msg.match(/[\.,?!]$/)
      puts "msg.match(/[\.,?!]$/) == true"
      if msg.match(/[\.?!]$/)
        puts "msg.match(/[\.?!]$/) == true"
      else
        puts "msg.match(/[\.?!]$/) == false"
        flags ^= Message::EOS
      end
    else
      puts "msg.match(/[\.,?!]$/) == false"
      flags ^= Message::PUNCTUATION
    end
  else
    puts "!msg.match(%r{^(?<esc>[\*\_]).+\k<esc>$}) == false"
    flags = Message::COMMENT
  end
  puts "eval_message -> #{flags}"
  flags
end

$MSGQUEUE = [] # TODO all the message events go here as long as the bot hasn't finished initializing

$bot.ready {
  $bot.on
  $bot.game = ""
  CHANNEL = $bot.servers[INFO[:server]].channels.select{|i|i.id==INFO[:channel]}.first

  loop{
    x = gets
    if x != nil && x.chomp.strip != ""
      $sentence << x.chomp
      puts "Added '#{$sentence[-1]}' to the sentence"
    end
  }
}

$last_message_sender = nil
process_message_str = lambda{ |msg, e=nil|
  msg_flags = eval_message msg
  out = false

  puts "[MESSAGE] '#{msg}' (flags: #{msg_flags})"

  if msg_flags == Message::COMMENT
    puts "Message was a comment, skipping."
    out = true
  end

  if e && e.message.author.discriminator == $last_message_sender && !out
    puts "Same user (#{e.message.author.username}##{e.message.author.discriminator}) tried to send two words"
    out = true
  end

  if $sentence == [] && !out
    puts "Punctuation was tried to make, but there were no words yet"
    out = fale
  end

  if flag_set?(msg_flags, Message::PUNCTUATION) && !out
    $sentence[-1] << msg
    puts "$sentence[-1] << msg"
    if e
      $last_message_sender = e.message.author.discriminator
      puts "$last_message_sender = #{e.message.author.discriminator}"
    end
  end

  if flag_set?(msg_flags, Message::EOS) && !out
    puts "Sentence finished, tweeting..."
    CHANNEL.send_message("*(Sentence finished, tweeting...)*")
    this_tweet = tweet
    puts "Done."
    CHANNEL.send_message("*(Done. https://twitter.com/vocdisc_owsarc/status/#{this_tweet.id})*")
    $last_message_sender = nil
    puts "$last_message_sender = nil"
    out = true
  end


  if flag_set?(msg_flags, Message::WORD) && !out
    $sentence << msg
    puts "$sentence << msg"
    if e
      $last_message_sender = e.message.author.discriminator
      puts "$last_message_sender = #{e.message.author.discriminator}"
    end
  end

}


$bot.message(in:INFO[:channel]){ |e|
  msg = e.message.to_s.strip
  process_message_str.call(msg, e)
}
