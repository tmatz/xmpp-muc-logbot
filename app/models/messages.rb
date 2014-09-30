class Message < Sequel::Model
  set_dataset DB[:messages]
  set_schema do
    primary_key :id, :integer
    column :from, :text, null: false
    column :text, :text
    column :room, :text, null: false
    column :mtime, :timestamp
  end

  def permalink
    "/messages/#{id}"
  end

  def to_json
    self.values.to_json
  end
end
