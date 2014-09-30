class App
  get '/admin/users' do
    @users = User.all
    haml :users
  end

  get '/admin/users/:id' do
    @id = params[:id]
    @user = User[@id]
    @setting = UserSetting[user_id: @id]
    not_found("") if @user.nil?
    haml :user
  end

  post '/admin/users' do
    user = User.create({
      name: params[:name],
      mtime: Time.now
    })
    setting = UserSetting.create({
      user_id: user.id,
      send_mail: params[:send_mail].nil? ? 0 : 1,
      mail_address: params[:mail_address],
      mtime: Time.now
    })
    redirect '/admin/users'
  end

  post '/admin/users/:id' do
    redirect "/admin/users"
  end

  put '/admin/users/:id' do
    DB.transaction do
      id = params[:id]
      user = User[id]
      not_found("") if user.nil?
      user.name = params[:name]
      user.mtime = Time.now
      user.save
      setting = UserSetting[user_id: id]
      if !setting.nil?
        setting.send_mail = params[:send_mail] ? 1 : 0
        setting.mail_address = params[:mail_address]
        setting.mtime = Time.now
        setting.save
      else
        UserSetting.create({
          user_id: id,
          send_mail: params[:send_mail] ? 1 : 0,
          mail_address: params[:mail_address],
          mtime: Time.now
        })
      end

      UserRole.filter(user_id: id).each do |r|
        join = params[:"role_#{r.role_id}"] ? 1 : 0
        if (r.join != join)
          r.mtime = Time.now
          r.save
        end
      end

      params.each do |key, value|
        if /role_(.*)/ =~ key
          role_id = $1.to_i
          userrole = UserRole[user_id: id, role_id: role_id]
          if userrole.nil?
            UserRole.create({
              user_id: id,
              role_id: role_id,
              join: 1,
              mtime: Time.now
            })
          end
        end
      end
    end
    redirect "/admin/users"
  end

  delete '/admin/users/:id' do
    DB.transaction do
      id = params[:id]
      User.filter(id: id).delete
      UserSetting.filter(user_id: id).delete
      UserRole.filter(user_id: id).delete
    end
    redirect "/admin/users"
  end
end
