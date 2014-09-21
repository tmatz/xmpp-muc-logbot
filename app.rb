#!/usr/bin/env ruby
#! coding: utf-8

require 'sinatra'
require 'oauth2'
require 'json'
require 'haml'
require 'sass'
require 'sequel'
require 'sqlite3'

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

  @db.create_table! :messages do
    primary_key :id
    String :from
    String :text
    int :room_id
    timestap :mtime
  end

  @db[:users].insert(name: 'guest', admin: 0, mtime: Time.now)
  @db[:users].insert(name: 'matsu', admin: 1, mtime: Time.now)
  @db[:users].insert(name: 'other', admin: 0, mtime: Time.now)

  @db[:roles].insert(name: 'guest', mtime: Time.now)
  @db[:roles].insert(name: 'all', mtime: Time.now)
  @db[:roles].insert(name: 'group', mtime: Time.now)

  @db[:userroles].insert(user_id: 1, role_id: 1, join: 1, mtime: Time.now)
  @db[:userroles].insert(user_id: 2, role_id: 2, join: 1, mtime: Time.now)
  @db[:userroles].insert(user_id: 2, role_id: 3, join: 1, mtime: Time.now)
  @db[:userroles].insert(user_id: 3, role_id: 2, join: 1, mtime: Time.now)

  @db[:rooms].insert(name: 'public', mtime: Time.now)
  @db[:rooms].insert(name: 'room1', mtime: Time.now)
  @db[:rooms].insert(name: 'room2', mtime: Time.now)

  @db[:permissions].insert(role_id: 1, room_id: 1, readable: 1, mtime: Time.now)
  @db[:permissions].insert(role_id: 2, room_id: 1, readable: 1, mtime: Time.now)
  @db[:permissions].insert(role_id: 2, room_id: 2, readable: 1, mtime: Time.now)
  @db[:permissions].insert(role_id: 3, room_id: 3, readable: 1, mtime: Time.now)

  @db[:messages].insert(from: 'nick1', text: 'message 1', room_id: 1, mtime: Time.now)
  @db[:messages].insert(from: 'nick2', text: 'message 2', room_id: 2, mtime: Time.now)
  @db[:messages].insert(from: 'nick3', text: 'message 3', room_id: 3, mtime: Time.now)
  @db[:messages].insert(from: 'nick4', text: 'message 4', room_id: 1, mtime: Time.now)
  @db[:messages].insert(from: 'nick5', text: 'message 5', room_id: 2, mtime: Time.now)
  @db[:messages].insert(from: 'nick6', text: 'message 6', room_id: 3, mtime: Time.now)
  @db[:messages].insert(from: 'nick7', text: 'message 7', room_id: 1, mtime: Time.now)
  @db[:messages].insert(from: 'nick8', text: 'message 8', room_id: 2, mtime: Time.now)
  @db[:messages].insert(from: 'nick9', text: 'message 9', room_id: 3, mtime: Time.now)
  @db[:messages].insert(from: 'nick0', text: 'message 0', room_id: 1, mtime: Time.now)
  @db[:messages].insert(from: 'nick1', text: 'message 1', room_id: 2, mtime: Time.now)
  @db[:messages].insert(from: 'nick2', text: 'message 2', room_id: 3, mtime: Time.now)
  @db[:messages].insert(from: 'nick3', text: 'message 3', room_id: 1, mtime: Time.now)

  public

  def self.get_user_id(username)
    users.where(:name => username).get(:id)
  end

  def self.readable?(user_id, room_id)
    ! userroles.where(:user_id => user_id).
      join(:permissions, :role_id => :role_id).
      where(:readable => 1).empty?
  end

  class User < Sequel::Model
  end

  class Role < Sequel::Model
  end

  class Userrole < Sequel::Model
  end

  class Room < Sequel::Model
  end

  class Permission < Sequel::Model
  end

  class Message < Sequel::Model
  end

  public

  def self.users
    @users ||= @db[:users]
  end

  def self.roles
    @roles ||= @db[:roles]
  end

  def self.userroles
    @userroles ||= @db[:userroles]
  end

  def self.rooms
    @rooms ||= @db[:rooms]
  end

  def self.permissions
    @permissions ||= @db[:permissions]
  end

  def self.messages
    @messages ||= @db[:messages]
  end

end

enable :sessions

CLIENT = "xmpp-muc-logbot"
CLIENT_SECRET = "xmpp-muc-logbot-secret"

def client
  $client ||= OAuth2::Client.new(CLIENT, CLIENT_SECRET, site: 'http://localhost:4000/')
end

get '/' do
  @user = session[:user]
  begin
    @user_id = get_user_id(@user)
  rescue
    @user_id = DB::GUEST_ID
  end
  haml :top
end

get '/login' do
  session[:login_key] = SecureRandom.hex(16);
  redirect client.auth_code.authorize_url(
    redirect_uri: redirect_uri,
    state: session[:login_key])
end

get '/logout' do
  session.delete(:user)
  haml :logout
end

get '/login/denied' do
  haml :denied
end

get '/auth/callback' do
  begin
    raise unless params[:code]
    raise unless params[:state] == session[:login_key]
    session.delete(:login_key)
    token = client.auth_code.get_token(
      params[:code],
      redirect_uri: redirect_uri)
    session[:user] = token.token
    redirect to('/')
  rescue
    session[:user] = nil
    redirect to('/login/denied')
  end
end

def redirect_uri
  uri = URI.parse(request.url)
  uri.path = '/auth/callback'
  uri.query = nil
  uri.to_s
end

__END__

@@layout
%html{:'ng-app' => "app"}
  %head
    %meta{:charset => "utf-8"}
    %meta{:'http-equiv' => "X-UA-Compatible", :content => "IE=edge"}
    %meta{:name => "viewport", :content => "width=device-width, initial-scale=1"}
    %title Chat Room Logger
    %link{:rel => "stylesheet", :href => "https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css"}
    %script{:src => "//ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js"}
    %script{:src => "//maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js"}
    %script{:src => "//ajax.googleapis.com/ajax/libs/angularjs/1.3.0-rc.2/angular.js"}
    %script{:src => "//ajax.googleapis.com/ajax/libs/angularjs/1.3.0-rc.2/angular-route.js"}
    %script{:src => "/ui-bootstrap-tpls-0.11.0.min.js"}
    %script{:src => "/client.js"}

    :sass
      body
        :padding-top 50px
      #content
        :padding 40px 15px

  %body{:'ng-controller' => "RoomCtrl"}
    %div.navbar.navbar-default.navbar-fixed-top
      %div.header
        %a.navbar-brand{:href => "/"} Chat Room Logger
        %ul.nav.navbar-nav.pull-right
          - if @user
            %li.dropdown
              %a.dropdown-toggle.active#user{:role => "button", :'data-toggle' => "dropdown"}
                = "#{@user} さん"
                %span.caret
              %ul.dropdown-menu{:role => "menu", :'aria-lablledby' => "user"}
                %li{:role => "presentation"}
                  %a{:role => "menuitem", :href => "/logout"} Logout
          - else
            %li.active
              %a{:href => "/login"} Login

    %div.container#content
      = yield

@@top
- if @user
  %div
    %label.checkbox
      %input{:type => "checkbox", :'ng-model' => "oneAtATime"} Open only one at a time
    %accordion{:'close-others' => "oneAtATime"}
      - DB::rooms.each do |r|
        - room_id = r[:id]
        - if DB::readable? @user_id, room_id
          - msgs = DB::messages.where(:room_id => room_id)
          - unless msgs.empty?
            %accordion-group{:heading => "#{r[:name]}"}
              %ul
                - msgs.each do |m|
                  %li= "#{m[:from]}: #{m[:text]}"

- else
  %p ログインしてください。

@@denied
%p Access Denied.

@@logout
%p ログアウトしました。
