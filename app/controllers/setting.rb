class App
  get '/setting' do
    not_found("") if @login_user.nil?
    haml :setting
  end

  post '/setting' do
    if @login_user
      setting = UserSetting[user_id: @login_user.id]
      if setting
        DB.transaction do
          setting.send_mail = params[:send_mail] ? 1 : 0
          setting.mail_address = params[:mail_address]
          setting.mtime = Time.new
          setting.save
        end
      else
        DB.transaction do
          setting = UserSetting.create({
            user_id: @login_user.id,
            send_mail: params[:send_mail] ? 1 : 0,
            mail_address: params[:mail_address],
            mtime: Time.new
          })
          setting.save
        end
      end
    end
    redirect to('/setting')
  end
end
