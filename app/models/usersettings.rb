class UserSetting < Sequel::Model
  set_dataset DB[:usersettings]
  set_schema do
    primary_key :id, :integer
    column :user_id, :integer, unique: true
    column :send_mail, :integer
    column :mail_address, :text, default: "", null: false
    column :mtime, :timestamp
  end

  def permalink
    "/usersettings/#{id}"
  end

  def to_json
    self.values.to_json
  end
end
