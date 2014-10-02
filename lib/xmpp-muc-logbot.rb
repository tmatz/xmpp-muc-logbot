#!/usr/bin/env ruby
#! coding: utf-8

require 'cgi'
require 'oauth2'
require 'sequel'
require 'sqlite3'
require 'active_support/time'
require 'blather/client/dsl'

require 'xmpp-muc-logbot/time'

$lock = Mutex.new
def log *message
  $lock.synchronize do
    $stderr.puts Time.now, *message
  end
end

module Storage

  private

  GUEST_ROLE = 1

  public

  def self.get_user_id(username)
    DB[:users].where(:name => username).get(:id)
  end

  def self.readable?(user_name, room_id)
    if user = User[name: user_name]
      ! DB[:userroles].where(:user_id => user.id, :join => 1).
        join(:permissions, :role_id => :role_id).
        where(:room_id => room_id, :readable => 1).empty?
    else
      ! DB[:permissions].where(:role_id => GUEST_ROLE, :room_id => room_id, :readable => 1).empty?
    end
  end

  def self.rooms
    @rooms ||= DB[:rooms]
  end

  def self.messages
    @messages ||= DB[:messages]
  end
end

class Blather::Stream
  def unbind
    cleanup

    @state = :stopped
    @client.receive_data @error if @error
    @client.unbind
  end
end

class MucBot
  def self.bots
    @bots ||= Hash.new
  end

  def self.run
    if bots.empty?
      Xmpp.all.each do |xmpp|
        bots[xmpp.id] = bot = MucBot.new
        bot.setup "#{xmpp.jid}/#{xmpp.nick}", xmpp.password
        Room.filter(xmpp_id: xmpp.id).each do |room|
          bot.join_room room.id, room.jid, room.nick
        end
      end
      bots.each do |k,v|
        v.run
      end
    end
  end

  def self.stop
    if ! bots.empty?
      bots.each do |k,v|
        v.close
      end
      bots.clear
    end
  end

  def self.rerun
    stop
    EM.add_timer(5) do
      run
    end
  end

  RoomInfo = Struct.new(:id, :jid, :nick, :block)

  def initialize
    @rooms = Hash.new
    @periodic_joins = Hash.new
  end

  def client
    unless @client
      @client = Blather::Client.new

      @client.register_handler :ready do
        log "connect #{@client.jid}"
        @ping_timer = EM.add_periodic_timer(30) do
          ping = Blather::Stanza::Iq::Ping.new
          begin
            client.write_with_handler ping do |s|
              #log "PING handler", s.inspect
              if s.error?
                close
                if @run
                  EM.add_timer(30) do
                    run
                  end
                end
              end
            end
          rescue => err
            log "MucBot.ping", err.insert, err.backtrace
            close
            EM.add_timer(30) do
              run
            end
          end
        end
        @rooms.each_value do |room|
          check_room_presence_and_join(room)
        end
      end

      @client.register_handler :disconnected do
        log "MucBot.disconnected"
        EM.cancel_timer(@ping_timer) if @ping_timer
        @ping_timer = nil
        @periodic_joins.each do |k,v|
          EM.cancel_timer v
        end
        @periodic_joins.clear

        if @run
          @run_timer = EM.add_timer(30) do
            run
          end
        end
        # continue EM loop
        true
      end

      @client.register_handler :iq do |i|
        log 'IQ', i
      end

      @client.register_handler :message, :groupchat?, :body, delay: nil do |m|
        room = @rooms[m.from.stripped.to_s]
        if room
          Storage.messages.insert(
            from: m.from.resource,
            text: m.body,
            room: m.from.stripped.to_s,
            mtime: Time.now)
        end
      end
    end
    @client
  end

  def setup *args
    client.setup(*args)
  end

  def join_room(id, jid, nick, &block)
    @rooms[jid] = room = RoomInfo.new(id, jid, nick, block)
    if client.connected?
      check_room_presence_and_join(room)
    end
  end

  def exit_room(id)
    @rooms.delete_if do |jid, room|
      if room.id == id
        if client.connected?
          pres = Blather::Stanza::Presence::MUC.new
          pres.to = "#{room.jid}/#{room.nick}"
          pres.type = :unavailable
          begin
            client.write pres
          rescue => err
            log 'MucBot EXIT', err.inspect, err.backtrace
          end
          log "exit #{room.jid}/#{room.nick}."
        end
        if timer = @periodic_joins.delete(jid)
          EM.cancel_timer timer
        end
        true
      else
        false
      end
    end
  end

  def run
    log 'MucBot.run'
    @run = true
    @run_timer = nil
    @ping_timer = nil
    begin
      client.run
    rescue => err
      log 'MucBot.run', err.inspect, err.backtrace
      @run_timer = EM.add_timer(30) do
        run
      end
    end
  end

  def close
    @run = false
    if @run_timer
      EM.cancel_timer(@run_timer)
      @run_timer = nil
    end
    if @ping_timer
      EM.cancel_timer(@ping_timer)
      @ping_timer = nil
    end
    client.close
  end

  def pubsub
    @pubsub ||= Blather::DSL::PubSub.new(client, client.jid.domain)
  end

  private

  def join(room, service, nickname = nil)
    join = Blather::Stanza::Presence::MUC.new
    join.to = if nickname
      "#{room}@#{service}/#{nickname}"
    else
      "#{room}/#{service}"
    end
    client.write join
  end

  def check_room_presence_and_join(room)
    #log 'MucBot.check_room_presence_and_join'
    begin
      pubsub.node nil, room.jid do |info|
        #log 'DISCO', info
        if info.error?
          log "ROOM DOES NOT EXISTS #{room.jid}"
        else
          begin
            join room.jid, room.nick
            log "join #{room.jid}/#{room.nick}."
            @periodic_joins[room.jid] = EM.add_periodic_timer(30 * 60) do
              join room.id, room.nick
            end
          rescue => err
            log 'JOIN', err.inspect, err.backtrace
          end
        end
      end
    rescue => err
      log 'DISCO', err.inspect, err.backtrace
    end
  end
end

CLIENT = "xmpp-muc-logbot"
CLIENT_SECRET = "xmpp-muc-logbot-secret"

module OAuth2

  # @return user, user_id
  def oauth2_authenticate
    if oauth2_client
      unless user = session[:user]
        session[:login_key] = SecureRandom.hex(16);
        redirect oauth2_client.auth_code.authorize_url(
          redirect_uri: redirect_uri,
          scope: 'user',
          state: session[:login_key])
      end
      session[:user]
    end
  end

  # @return user
  def oauth2_process_callback
    if oauth2_client
      begin
        raise unless params[:code]
        raise unless params[:state] == session[:login_key]
        session.delete(:login_key)
        token = oauth2_client.auth_code.get_token(
          params[:code],
          scope: 'user',
          redirect_uri: redirect_uri)
        #puts 'TOKEN', token.inspect
        session[:user] = token.token
      rescue => err
        session[:user] = nil
      end
    end
  end

  def redirect_uri
    uri = URI.parse(request.url)
    uri.path = '/login/callback'
    uri.query = nil
    uri.to_s
  end

end

module LogMail
  def self.from_address
    "admin@sample.org"
  end

  def self.user_mail_address(username)
    "#{username}@sample.org"
  end

  def self.latest_url
    nil
  end

  def self.enabled?
    info = LogmailInfo[1]
    info and info.enable != 0 and info.hour != nil
  end

  def self.schedule
    EM.cancel_timer(@timer) if @timer
    @timer = nil

    if enabled?
      info = LogmailInfo[1]
      hour = info.hour
      @timer = EM.add_timer(Time.now.seconds_to_next_hour(hour)) do
        scheduled_send_mail(hour)
      end
    end
  end

  def self.send_mail(delete_log = false)
    return unless enabled?

    EM.schedule do
      begin
        now = Time.now
        Room.all.each do |room|
          ignored =
            DB[:permissions].where(room_id: room.id, readable: 1).
            join(:roles, :id => :role_id).
            join(:userroles, :role_id => :id).
            join(:users, :id => :user_id).
            empty?
          next if ignored

          msgs = Message.filter(room: room.jid)
          next if msgs.empty?

          text = msgs.map { |m|
            "(#{Time.parse(m.mtime).strftime('%F %T')}) #{m.from}: #{m.text}"
          }.join("\n")

          text = "MUC JID: #{room.jid.sub('@', ' @ ')}\nDate: #{now.strftime('%F')}\n\n" + text

          if latest_url = LogMail.latest_url
            text += "\n\n最新はこちら\n#{latest_url}"
          end

          User.all.each do |user|
            setting = UserSetting[user_id: user.id]
            next if setting.nil? || setting.send_mail == 0
            next if ! Storage.readable?(user.name, room.id)

            mail = Mail.new do
              from LogMail.from_address
              to LogMail.user_mail_address(user.name)
              subject "[Chat Room Logger] #{now.strftime('%F')} #{room.jid}"
              body text
            end

            mail.charset = 'utf-8'
            mail.deliver
          end
        end
        Message.dataset.delete if delete_log
      rescue => err
        log 'MAIL', err.inspect, err.backtrace
      end
    end
  end

  private

  def self.scheduled_send_mail(hour)
    if enabled?
      begin
        send_mail(true)
      rescue
      end

      @timer = EM.add_timer(Time.now.seconds_to_next_hour(hour)) do
        scheduled_send_mail(hour)
      end
    end
  end
end

