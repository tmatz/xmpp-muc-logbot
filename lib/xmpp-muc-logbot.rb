#!/usr/bin/env ruby
#! coding: utf-8

require 'eventmachine'
require 'sinatra/base'
require 'thin'
require 'oauth2'
require 'json'
require 'haml'
require 'sass'
require 'sequel'
require 'sqlite3'
require 'blather/client/dsl'

$lock = Mutex.new
def log *message
  $lock.synchronize do
    $stderr.puts Time.now, *message
  end
end

module DB
  @db = Sequel.connect('sqlite://store.db')

  GUEST_ID = 1

  private

  @db.create_table! :users do
    primary_key :id
    String :name, null: false, unique: true
    int :admin
    timestamp :mtime
  end

  @db.create_table! :roles do
    primary_key :id
    String :name, null: false, unique: true
    timestamp :mtime
  end

  @db.create_table! :userroles do
    primary_key :id
    int :user_id
    int :role_id
    int :join
    timestamp :mtime
  end

  @db.create_table! :permissions do
    primary_key :id
    int :role_id
    int :room_id
    int :readable
    timestamp :mtime
  end

  @db.create_table! :rooms do
    primary_key :id
    String :name, null: false
    timestamp :mtime
  end

  @db.create_table? :messages do
    primary_key :id
    String :from
    String :text
    int :room_id
    timestap :mtime
  end

  @db.create_table? :usersetting do
    primary_key :id
    int :user_id, unique: true
    int :send_mail
    String :mail_address
    timestap :mtime
  end

  @db[:users].insert(name: 'guest', admin: 0, mtime: Time.now)

  @db[:roles].insert(name: 'guest', mtime: Time.now)
  @db[:roles].insert(name: 'user', mtime: Time.now)

  @db[:userroles].insert(user_id: 1, role_id: 1, join: 1, mtime: Time.now)


  @db[:users].insert(name: 'matsu', admin: 1, mtime: Time.now)

  @db[:userroles].insert(user_id: 2, role_id: 2, join: 1, mtime: Time.now)

  @db[:rooms].insert(name: 'public', mtime: Time.now)
  @db[:rooms].insert(name: 'room1', mtime: Time.now)
  @db[:rooms].insert(name: 'room2', mtime: Time.now)
  @db[:rooms].insert(name: 'room3', mtime: Time.now)

  @db[:permissions].insert(role_id: 1, room_id: 1, readable: 1, mtime: Time.now)
  @db[:permissions].insert(role_id: 2, room_id: 1, readable: 1, mtime: Time.now)
  @db[:permissions].insert(role_id: 2, room_id: 2, readable: 1, mtime: Time.now)
  @db[:permissions].insert(role_id: 2, room_id: 3, readable: 1, mtime: Time.now)
  @db[:permissions].insert(role_id: 2, room_id: 4, readable: 1, mtime: Time.now)

  public

  def self.get_user_id(username)
    @db[:users].where(:name => username).get(:id)
  end

  def self.readable?(user_id, room_id)
    ! @db[:userroles].where(:user_id => user_id, :join => 1).
      join(:permissions, :role_id => :role_id).
      where(:room_id => room_id, :readable => 1).empty?
  end

  def self.rooms
    @rooms ||= @db[:rooms]
  end

  def self.messages
    @messages ||= @db[:messages]
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

module MucBot
  extend Blather::DSL

  Room = Struct.new(:id, :jid, :nick, :block)

  @rooms = Hash.new
  @periodic_joins = Hash.new

  def self.join_room(id, jid, nick, &block)
    @rooms[jid] = room = Room.new(id, jid, nick, block)
    if client.connected?
      check_room_presence_and_join(room)
    end
  end

  def self.exit_room(id)
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
        @periodic_joins.delete(jid)
        true
      else
        false
      end
    end
  end

  def self.run!
    log 'MucBot.run!'
    begin
      client.run
    rescue => err
      log 'MucBot RUN', err.inspect, err.backtrace
      EM.add_timer(30) do
        MucBot.run
      end
    end
  end

  private

  def self.check_room_presence_and_join(room)
    log 'MucBot.check_room_presence_and_join'
    begin
      pubsub.node nil, room.jid do |info|
        log 'DISCO', info
        if info.error?
          log "ROOM DOES NOT EXISTS #{room.jid}"
        else
          begin
            join room.jid, room.nick
            log "join #{room.jid}/#{room.nick}."
          rescue => err
            log 'JOIN', err.inspect, err.backtrace
          end
        end
      end
    rescue => err
      log 'DISCO', err.inspect, err.backtrace
    end
  end

  when_ready do
    log "MucBot.when_ready"
    @rooms.each_value do |room|
      check_room_presence_and_join(room)
    end
  end

  disconnected do
    log "MucBot.disconnected"
    @periodic_joins.each do |k,v|
      EM.cancel_timer v
    end
    @periodic_joins.clear

    EM.add_timer(30) do
      MucBot.run
    end
  end

  iq do |i|
    log 'IQ', i
  end

  message do |m|
    log 'MESSAGE', m
  end

  presence do |p|
    log 'PRESENCE', p
  end

  message :groupchat?, :body, delay: nil do |m|
    room = @rooms[m.from.stripped.to_s]
    if room
      DB.messages.insert(
        from: m.from.resource,
        text: m.body,
        mtime: Time.now,
        room_id: room.id)
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
        puts 'TOKEN', token.inspect
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
