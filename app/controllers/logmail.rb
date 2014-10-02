class App
  get '/admin/logmail' do
    @info = LogmailInfo.first
    haml :logmail
  end

  post '/admin/logmail' do
    enable = params[:enable] ? 1 : 0

    hour = nil
    case params[:hour]
    when nil, /^\s*$/
        hour = nil
    else
      val = params[:hour].to_i
      if 0 <= val and val <= 23
          hour = val
      else
          hour = nil
      end
    end

    info = LogmailInfo.first
    info.enable = enable
    info.hour = hour
    info.mtime = Time.now
    info.save

    redirect to('/admin/logmail')
  end

  get '/admin/logmail/send' do
    LogMail.send_mail
    redirect to('/admin/logmail')
  end
end
