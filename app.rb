#!/usr/bin/env ruby
#! coding: utf-8

require 'sinatra'
require 'oauth2'
require 'songkick/oauth2/provider'
require 'json'
require 'haml'
require 'sass'
require 'sequel'
require 'sqlite3'

module DB
  db = Sequel.connect('sqlite://store.db')
  db.create_table! :users do
    primary_key :id
    String :name, null: false
    timestamp :mtime
  end
  db.create_table! :rooms do
    primary_key :id
    String :name, null: false
    timestamp :mtime
  end
  db.create_table! :rights do
    primary_key :id
    int :user_id
    int :room_id
    timestamp :mtime
  end
  db.create_table! :messages do
    primary_key :id
    String :from
    String :text
    int :room_id
    timestap :mtime
  end
  db[:users].insert(name: 'admin', mtime: Time.now)
  db[:users].insert(name: 'matsu', mtime: Time.now)
  db[:users].insert(name: 'guest', mtime: Time.now)
  db[:rooms].insert(name: 'room1', mtime: Time.now)
  db[:rooms].insert(name: 'room2', mtime: Time.now)
  db[:rights].insert(user_id: 1, room_id: 1, mtime: Time.now)
  db[:rights].insert(user_id: 1, room_id: 2, mtime: Time.now)
  db[:rights].insert(user_id: 2, room_id: 1, mtime: Time.now)
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
  haml :top
end

get '/login' do
  redirect client.auth_code.authorize_url(redirect_uri: redirect_uri)
end

get '/logout' do
  session[:access_token] = nil
  haml :logout
end

get '/login/denied' do
  haml :denied
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
    %div.navbar.navbar-inverse.navbar-fixed-top
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
      %accordion-group{:heading => "{{room.title}}", :'ng-repeat' => "room in rooms"} {{room.contents}}

@@denied
%p Access Denied.

@@logout
%p ログアウトしました。
