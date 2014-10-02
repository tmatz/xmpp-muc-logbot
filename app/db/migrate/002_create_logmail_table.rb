Sequel.migration do
  up do
    create_table :logmail_info do
      primary_key :id
      int :enable, null: false, default: 0
      int :hour
      timestamp :mtime
    end
    from(:logmail_info).insert(id: 1, enable: 0, hour: nil, mtime: Time.now)
  end

  down do
    drop_table :logmail_info
  end
end
