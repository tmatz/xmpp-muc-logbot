class Room < Sequel::Model
  set_dataset DB[:rooms]
  set_schema do
    primary_key :id, :integer
    column :xmpp_id, :integer
    column :jid, :text, null: false
    column :nick, :text, null: false
    column :password, :text
    column :mtime, :timestamp
  end

  def permalink
    "/rooms/#{id}"
  end

  def to_json
    self.values.to_json
  end
end
