Sequel.migration do
  up do
    create_table :users do
      primary_key :id
      String :name, null: false, unique: true
      timestamp :mtime
    end

    create_table :roles do
      primary_key :id
      String :name, null: false, unique: true
      timestamp :mtime
    end

    create_table :userroles do
      primary_key :id
      int :user_id
      int :role_id
      int :join
      timestamp :mtime
    end

    create_table :permissions do
      primary_key :id
      int :role_id
      int :room_id
      int :readable
      timestamp :mtime
    end

    create_table :usersettings do
      primary_key :id
      int :user_id, unique: true
      int :send_mail
      String :mail_address
      timestap :mtime
    end

    create_table :xmpps do
      primary_key :id
      String :jid, null: false
      String :nick, null: false
      String :password
      timestamp :mtime
    end

    create_table :rooms do
      primary_key :id
      int :xmpp_id
      String :jid, null: false
      String :nick, null: false
      String :password
      timestamp :mtime
    end

    create_table :messages do
      primary_key :id
      String :from, null: false
      String :text
      String :room, null: false
      timestap :mtime
    end

    from(:roles).insert(id: 1, name: 'guest', mtime: Time.now)
  end

  down do
    drop_table :users
    drop_table :roles
    drop_table :userroles
    drop_table :permissions
    drop_table :usersettings
    drop_table :xmpps
    drop_table :rooms
    drop_table :messages
  end
end
