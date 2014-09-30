class App
  get '/permissions' do
    haml :permissions
  end

  get '/permissions/:id' do
    @entry = Permission[id: params[:id]]
    not_found(nil.to_json) if !@entry
    body @entry.to_json
  end

  get '/permissions/new' do
    haml :new
  end

  post '/permissions/new' do
    @entry = Permission.create(params)
    status 201
    header 'Location' => "/permissions/#{@entry.id}"
    body "/permissions/#{@entry.id}"
  end

  put '/permissions/:id' do
    @entry = Permission[id: params[:id]]
    not_found("") if !@entry
    [:role_id, :room_id, :readable].each do |key|
      @entry[key] = params[key]
    end
    @entry[:mtime] = Time.now
    @entry.save
    redirect "/permissions/#{@entry[:id]}"
  end
end
