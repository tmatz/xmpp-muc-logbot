class LogmailInfo < Sequel::Model
  set_dataset DB[:logmail_info]
  set_schema do
    primary_key :id, :integer
    column :enable, :integer, default: 0, null: false
    column :hour, :integer
    column :mtime, :timestamp
  end

  def to_json
    self.values.to_json
  end
end
