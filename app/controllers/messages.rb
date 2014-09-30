class App
  get '/messages/room/:room' do
    @messages = Message[room: params[:room]]
    not_found(nil.to_json) if !@messages
    body @messages.to_json
  end
end
