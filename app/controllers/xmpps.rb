class App
  get '/admin/xmpps' do
    haml :xmpps
  end

  post '/admin/xmpps' do
    @xmpp = Xmpp.create({
      jid: params[:jid],
      nick: "",
      password: "",
      mtime: Time.now
    })
    redirect to('/admin/xmpps')
  end

  get '/admin/xmpps/:id' do
    @id = params[:id]
    @xmpp = Xmpp[@id]
    not_found("") if @xmpp.nil?
    haml :xmpp
  end

  post '/admin/xmpps/:id' do
    @xmpp_id = params[:id]
    @xmpp = Xmpp[@xmpp_id]
    not_found("") if @xmpp.nil?
    room = Room.create({
      xmpp_id: @xmpp_id,
      jid: params[:jid],
      nick: "",
      password: "",
      mtime: Time.now
    })
    redirect to("/admin/xmpps/#{@xmpp_id}")
  end

  put '/admin/xmpps/:id' do
    DB.transaction do
      id = params[:id]
      xmpp = Xmpp[id]
      not_found("") if xmpp.nil?
      xmpp.jid = params[:jid]
      xmpp.nick = params[:nick]
      xmpp.password = params[:password]
      xmpp.mtime = Time.now
      xmpp.save
    end
    redirect to("/admin/xmpps")
  end

  delete '/admin/xmpps/:id' do
    DB.transaction do
      id = params[:id]
      Xmpp.filter(id: id).delete
      Room.filter(xmpp_id: id).delete
    end
    redirect to("/admin/xmpps")
  end

  get '/admin/xmpps/:xmpp_id/rooms/:room_id' do
    @xmpp_id = params[:xmpp_id]
    @room_id = params[:room_id]
    @xmpp = Xmpp[@xmpp_id]
    @room = Room[@room_id]
    not_found("") if @xmpp.nil? or @room.nil?
    haml :room
  end

  put '/admin/xmpps/:xmpp_id/rooms/:room_id' do
    xmpp_id = params[:xmpp_id]
    room_id = params[:room_id]
    room = Room[room_id]
    not_found("") if room.nil?
    DB.transaction do
      room.jid = params[:jid]
      room.nick = params[:nick]
      room.password = params[:password]
      room.mtime = Time.now
      room.save
    end
    redirect to("/admin/xmpps/#{xmpp_id}")
  end

  delete '/admin/xmpps/:xmpp_id/rooms/:room_id' do
    xmpp_id = params[:xmpp_id]
    room_id = params[:room_id]
    DB.transaction do
      Room.filter(id: room_id).delete
    end
    redirect to("/admin/xmpps/#{xmpp_id}")
  end
end
