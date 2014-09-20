#!/usr/bin/env ruby
#! coding: utf-8

require 'sinatra'
require 'oauth2'
require 'songkick/oauth2/provider'
require 'json'
require 'slim'
require 'sass'
require 'sequel'

module DB
  db = Sequel.connect('sqlite://store.db')
  db.create_table! :users do
    primary_key :id
    String :name, null: false
    timestamp :mtime
  end
  db[:users].insert(name: 'admin', mtime: Time.now)
  db[:users].insert(name: 'matsu', mtime: Time.now)
  db[:users].insert(name: 'guest', mtime: Time.now)
  db.create_table! :rooms do
    primary_key :id
    String :name, null: false
    timestamp :mtime
  end
  db[:rooms].insert(name: 'room1', mtime: Time.now)
  db[:rooms].insert(name: 'room2', mtime: Time.now)
  db.create_table! :access_rights do
    primary_key :id
    foreign_key :user_id, :users
    foreign_key :room_id, :rooms
    timestamp :mtime
  end
  db[:access_rights].insert(user_id: 1, room_id: 1, mtime: Time.now)
  db[:access_rights].insert(user_id: 1, room_id: 2, mtime: Time.now)
  db[:access_rights].insert(user_id: 2, room_id: 1, mtime: Time.now)
  db.create_table! :messages do
    primary_key :id
    String :from
    String :text
    foreign_key :room_id, :rooms
    timestap :mtime
  end
  db[:messages].insert(from: 'nick1', text: 'message 1', room_id: 1, mtime: Time.now)
  db[:messages].insert(from: 'nick2', text: 'message 2', room_id: 2, mtime: Time.now)
  db[:messages].insert(from: 'nick3', text: 'message 3', room_id: 1, mtime: Time.now)
end

enable :sessions

CLIENT = "client"
CLIENT_SECRET = "secret"

def client
  $client ||= OAuth2::Client.new(CLIENT, CLIENT_SECRET, site: 'http://localhost:4000/')
end

get '/' do
  @user = session[:user]
  slim :top
end

get '/login' do
  redirect client.auth_code.authorize_url(redirect_uri: redirect_uri)
end

get '/logout' do
  session[:access_token] = nil
  slim :logout
end

get '/login/denied' do
  slim :denied
end

get '/auth/callback' do
  begin
    raise unless params[:code]
    session[:user] = client.auth_code.get_token(params[:code], redirect_uri: redirect_uri).token
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
doctype html
html lang="ja"
  head
    meta charset="utf-8"
    meta http-equiv="X-UA-Compatible" content="IE=edge"
    meta name="viewport" content="width=device-width, initial-scale=1"
    title
      | Chat Room Logger

    link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css"

  body
    div.container
      div.header
        ul.nav.navbar-nav.pull-right
          - if @user
            li.dropdown
              a#user.dropdown-toggle.active role="button" data-toggle="dropdown"
               | #{@user}さん 
               span.caret
              ul.dropdown-menu role="menu" aria-lablledby="user"
                li role="presentation"
                  a role="menuitem" href="/logout" Logout
          - else
            li.active
              a href="/login" Login
        h3.text-muted Chat Room Logger

    div.container
      div.starter-template
        == yield

    script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"
    script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js"

@@top
doctype html
div.dropdown
  button#room.btn.btn-default.dropdown-toggle type="button" data-toggle="dropdown"
    | Room 1 
    span.caret
  ul.dropdown-menu role="menu" aria-labelledby="room"
    li.presentation
      a role="menuitem" href="#" Room 1
    li.presentation
      a role="menuitem" href="#" Room 2
    li.presentation
      a role="menuitem" href="#" Room 3
ul
 li messsage
 li messsage
 li messsage
 li messsage
 li messsage
 li .. 

@@denied
doctype html
h2 Access Denied.

@@logout
doctype html
h3 ログアウトしました。
