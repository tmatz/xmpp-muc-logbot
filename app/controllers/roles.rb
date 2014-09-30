class App
  get '/admin/roles' do
    @entries = Role.all
    haml :roles
  end

  get '/admin/roles/:id' do
    @id = params[:id]
    @entry = Role[@id]
    not_found("") if @entry.nil?
    haml :role
  end

  post '/admin/roles' do
    @entry = Role.create(params)
    redirect '/admin/roles'
  end

  post '/admin/roles/:id' do
    redirect "/admin/roles"
  end

  put '/admin/roles/:id' do
    id = params[:id]
    entry = Role[id]
    not_found("") if entry.nil?
    [:name].each do |key|
      entry[key] = params[key]
    end
    entry[:mtime] = Time.now
    entry.save
    redirect "/admin/roles"
  end

  delete '/admin/roles/:id' do
    id = params[:id]
    @entry = Role[id]
    not_found("") if @entry.nil?
    @entry.delete
    userroles = UserRole[role_id: id]
    userroles.delete if !userroles.nil?
    redirect "/admin/roles"
  end
end
