class Role < Sequel::Model
  set_dataset DB[:roles]
  set_schema do
    primary_key :id, :integer
    column :name, :text, null: false, unique: true
    column :mtime, :timestamp
  end

  def permalink
    "/roles/#{id}"
  end

  def to_json
    self.values.to_json
  end
end
