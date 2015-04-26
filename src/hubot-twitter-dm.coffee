# Hubot dependencies
{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response, User} = require 'hubot'
###
try
    {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
    console.log 'catch'
    prequire = require 'parent-require'
    {Robot,Adapter,TextMessage,User} = prequire 'hubot'
###

HTTPS        = require 'https'
EventEmitter = require('events').EventEmitter
oauth        = require('oauth')

class TwitterDm extends Adapter

  #constructor: ->
    #super
    #@robot.logger.info "Constructor"

  send: (user, strings...) ->
    #console.log 'sent'
    console.log "Sending strings to user: " + user.screen_name
    strings.forEach (str) =>
      text = str
      tweetsText = str.split('\n')
      tweetsText.forEach (tweetText) =>
        @bot.send(user.user.user, tweetText, user.user.status_id )
    @robot.logger.info "Send"

  reply: (envelope, strings...) ->
    console.log "Replying"
    strings.forEach (text) =>
      @bot.send(user,text)
    @robot.logger.info "Reply"

  run: ->
    self = @
    options =
      key         : process.env.HUBOT_TWITTER_KEY || 'uGIGeozmGTKprY9pgTvV44PTF'
      secret      : process.env.HUBOT_TWITTER_SECRET || '4zWwLzLQHP0Y1g1OiCAXDmLqtwUn33bHsigxFhNiX5fVspcKB8'
      token       : process.env.HUBOT_TWITTER_TOKEN || '104734817-gsFrKLdK5LGbNroRgtSC4DGsL6fVlr84DpMtubKN'
      tokensecret : process.env.HUBOT_TWITTER_TOKEN_SECRET || 'FedZRGCPwv8MAxw4yvWANlhJsGdg7gtszxfD0IjcshLdO'

    bot = new TwitterDmStreaming(options)
    @emit "connected"
    #@x = 0
    bot.dirMsg self.robot.name, (data, err) ->
      if data.direct_message == undefined
        return
      reg = new RegExp('@'+self.robot.name,'i')
      dm = data.direct_message
      #console.log "dm: #{dm}"
      console.log "received #{dm.text} from #{dm.sender.screen_name}"

      msg = dm.text.replace reg, self.robot.name
      tmsg = new TextMessage({ user: dm.sender.screen_name, status_id: dm.id_str }, msg)
      self.receive tmsg
      if err
        console.log "received error: #{err}"

    @bot = bot

exports.use = (robot) ->
  new TwitterDm robot

class TwitterDmStreaming extends EventEmitter

  self = @;
  constructor: (options) ->
    if options.token? and options.secret? and options.key? and options.tokensecret?
      @token         = options.token
      @secret        = options.secret
      @key           = options.key
      @domain        = 'userstream.twitter.com'
      @tokensecret   =  options.tokensecret
      @consumer = new oauth.OAuth "https://twitter.com/oauth/request_token",
                           "https://twitter.com/oauth/access_token",
                           @key,
                           @secret,
                           "1.0A",
                           "",
                           "HMAC-SHA1"
    else
      throw new Error("Not enough parameters provided. I need a key, a secret, a token, a secret token")

  dirMsg: (track,callback) ->
   @post "/1.1/user.json?track=#{track}", '', callback

  send: (user, tweetText, in_reply_to_status_id) ->
    console.log "send twitt to #{user} with text #{tweetText}"
    @consumer.post "https://api.twitter.com/1.1/direct_messages/new.json", @token, @tokensecret, { text: "@#{user} #{tweetText}", user_id: in_reply_to_status_id, screen_name: user },'UTF-8',  (error, data, response) ->
      if error
        console.log "twitter send error: #{error} #{data}"
        console.log "Status #{response.statusCode}"
# Convenience HTTP Methods for posting on behalf of the token"d user
  get: (path, callback) ->
    @request "GET", path, null, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  request: (method, path, body, callback) ->
    data_append = ''
    console.log "https://#{@domain}#{path}, #{@token}, #{@tokensecret}, null"

    request = @consumer.get "https://#{@domain}#{path}", @token, @tokensecret, null

    request.on "response", (response) ->
      response.on "data", (chunk) ->
        console.log 'Rdata'
        parseResponse chunk+'',callback

      response.on "end", (data) ->
        console.log 'end request'

      response.on "error", (data) ->
        console.log 'error '+data

    request.end()

    parseResponse = (data,callback) ->
      data = data_append + data
      if ((index = data.indexOf('\r\n')) > -1)
        json = data.slice(0, index)
        data = data.slice(index + 2)

        if json.length > 0
          try
            callback JSON.parse(json), null
            data_append = ''
          catch err
             console.log err
      else
        data_append = data
