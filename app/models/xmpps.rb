class Xmpp < Sequel::Model
  set_dataset DB[:xmpps]
  set_schema do
    primary_key :id, :integer
    column :jid, :text, null: false
    column :nick, :text, null: false
    column :password, :text, null: false
    column :mtime, :timestamp
  end

  def permalink
    "/xmpps/#{id}"
  end

  def to_json
    self.values.to_json
  end
end
