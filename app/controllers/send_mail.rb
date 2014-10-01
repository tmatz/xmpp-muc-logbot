class App
  get '/admin/send_mail' do
    send_mail
    redirect to('/admin')
  end
end
