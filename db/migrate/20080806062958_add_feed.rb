class AddFeed < ActiveRecord::Migration
  def self.up
    add_column "projects", "feed_url", :string
  end

  def self.down
    remove_column "projects", "feed_url"
  end
end
