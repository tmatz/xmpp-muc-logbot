class Permission < Sequel::Model
  set_dataset DB[:permissions]
  set_schema do
    primary_key :id, :integer
    column :role_id, :integer
    column :room_id, :integer
    column :readable, :integer
    column :mtime, :timestamp
  end

  def permalink
    "/permissions/#{id}"
  end

  def to_json
    self.values.to_json
  end
end
