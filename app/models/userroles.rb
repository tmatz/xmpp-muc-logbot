class UserRole < Sequel::Model
  set_dataset DB[:userroles]
  set_schema do
    primary_key :id, :integer
    column :user_id, :integer
    column :role_id, :integer
    column :join, :integer
    column :mtime, :timestamp
  end

  def permalink
    "/userroles/#{id}"
  end

  def to_json
    self.values.to_json
  end
end
