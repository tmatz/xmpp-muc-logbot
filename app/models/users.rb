class User < Sequel::Model
  set_dataset DB[:users]
  set_schema do
    primary_key :id, :integer
    column :name, :text, null: false, unique: true
    column :mtime, :timestamp
  end

  def permalink
    "/users/#{id}"
  end

  def to_json
    self.values.to_json
  end
end
