class App
  get '/admin/roles' do
    @entries = Role.all
    haml :roles
  end

  post '/admin/roles' do
    @entry = Role.create(params)
    redirect to('/admin/roles')
  end

  get '/admin/roles/:id' do
    @id = params[:id]
    @entry = Role[@id]
    not_found("") if @entry.nil?
    haml :role
  end

  put '/admin/roles/:id' do
    role_id = params[:id]
    role = Role[role_id]
    not_found("") if role.nil?
    DB.transaction do
      [:name].each do |key|
        role[key] = params[key]
      end
      role[:mtime] = Time.now
      role.save
      params.each do |key, value|
        if /perm_(.*)/ =~ key
          room_id = $1.to_i
          if Permission[role_id: role_id, room_id: room_id].nil?
            perm = Permission.create({
              role_id: role_id,
              room_id: room_id,
              readable: 1,
              mtime: Time.now
            })
            perm.save
          end
        end
      end
      Permission.filter(role_id: role_id).each do |perm|
        readable = params["perm_#{perm.room_id}"] ? 1 : 0
        if perm.readable != readable
          perm.readable = readable
          perm.mtime = Time.now
          perm.save
        end
      end
    end
    redirect to("/admin/roles")
  end

  delete '/admin/roles/:id' do
    role_id = params[:id]
    role = Role[role_id]
    not_found("") if role.nil?
    DB.transaction do
      role.delete
      userroles = UserRole[role_id: role_id]
      userroles.delete if !userroles.nil?
    end
    redirect to("/admin/roles")
  end
end
