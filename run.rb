load "lib.rb"

ADMIN = "4998"

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
  flags = 0
  if !msg.match(%r{^(?<esc>[\*\_]).+\k<esc>$})
    #puts "!msg.match(%r{^(?<esc>[\*\_]).+\k<esc>$}) == true"
    flags |= Message::WORD
    if msg.match(/[\.,?!]$/)
      #puts "msg.match(/[\.,?!]$/) == true"
      flags |= Message::PUNCTUATION
      if msg.match(/[\.?!]$/)
        #puts "msg.match(/[\.?!]$/) == true"
        flags |= Message::EOS
      else
        #puts "msg.match(/[\.?!]$/) == false"
      end
    else
      #puts "msg.match(/[\.,?!]$/) == false"
    end
  else
    #puts "!msg.match(%r{^(?<esc>[\*\_]).+\k<esc>$}) == false"
    flags = Message::COMMENT
  end
  #puts "eval_message -> #{flags}"
  flags
end

$MSGQUEUE = [] # TODO all the message events go here as long as the bot hasn't finished initializing
$booted = false

$bot.ready {
  puts "Bot booting."
  puts "defined?(TOKEN) = #{(defined? TOKEN).inspect}"
  CHANNEL = $bot.servers[INFO[:server]].channels.select{|i|i.id==INFO[:channel]}.first
  puts "defined?(CHANNEL) = #{(defined? TOKEN).inspect}"

  _messages = Discordrb::API::Channel.messages(TOKEN, INFO[:channel], 100)
  puts "defined?(_messages) = #{(defined? _messages).inspect}"

  _messages = JSON.parse(_messages.body).reverse.map do |i|
    _str = Struct.new(:channel_id, :id, :content, :username, :discriminator)
    _arr = i.values_at("channel_id", "id", "content") + i["author"].values_at("username", "discriminator")
    eval "_str.new(#{_arr.map(&:inspect).join(?,)})"
  end

  # get the unfinished sentence:
  _unfinished_sentence_index = _messages.reverse.map(&:content).map{|i|i =~ /[\.?!]$/}.index(0)
  _unfinished_sentence = _messages.reverse[0..._unfinished_sentence_index].reverse

  _unfinished_sentence.each{|i|$process_message_str.call(i)}

  $MSGQUEUE.each{|i|msg = e.message.to_s.strip; $process_message_str.call(msg, e)}
  $MSGQUEUE.clear

  puts "FINISHED BOOT SEQUENCE."
  puts "$SENTENCE = #{$sentence.join(" ").inspect}"
  $booted = true

  $bot.on

  loop{
    x = gets
    if x != nil && x.chomp.strip != ""
      $sentence << x.chomp
      puts "Added '#{$sentence[-1]}' to the sentence"
    end
  }
}

$last_message_sender = nil
$process_message_str = lambda{ |msg_, e=nil|

  _username = nil
  _discriminator = nil

  msg = nil

  if msg_.inspect[0..7] == "#<struct"
    _username = msg_.username
    _discriminator = msg_.discriminator
    msg = msg_.content
  else
    _username = e.message.author.username
    _discriminator = e.message.author.discriminator
    msg = msg_
  end

  msg_flags = eval_message msg
  out = false

  puts "[MESSAGE] '#{msg}' (flags: #{msg_flags})"

  if msg_flags == Message::COMMENT
    puts "Message was a comment, skipping."
    out = true
  end

  if _discriminator != ADMIN && _discriminator == $last_message_sender && !out
    puts "Same user (#{_username}##{_discriminator}) tried to send two words"
    out = true
  end

  if $sentence == [] && flag_set?(msg_flags, Message::PUNCTUATION) && !out
    puts "Punctuation was tried to make, but there were no words yet"
    out = true
  end

  if flag_set?(msg_flags, Message::PUNCTUATION) && !out
    $sentence[-1] << msg
    puts "$sentence[-1] << msg"
    if e
      $last_message_sender = _discriminator
      puts "$last_message_sender = #{_discriminator}"
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
      $last_message_sender = _discriminator
      puts "$last_message_sender = #{_discriminator}"
    end
  end

}


$bot.message(in:INFO[:channel]){ |e|
  msg = e.message.to_s.strip
  $booted ? $process_message_str.call(msg, e) : $MSGQUEUE.push(e)
}
