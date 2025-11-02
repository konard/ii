class CreateVkPosts < ActiveRecord::Migration[7.2]
  def change
    create_table :vk_posts do |t|
      t.string  :keyword, null: false, index: true
      t.bigint  :owner_id
      t.string  :owner_name
      t.bigint  :post_id
      t.datetime :published_at
      t.integer :likes, default: 0
      t.integer :reposts, default: 0
      t.integer :comments, default: 0
      t.integer :views, default: 0
      t.integer :engagement, default: 0, index: true
      t.string  :link
      t.text    :text_snippet
      t.timestamps
    end
    add_index :vk_posts, [:keyword, :post_id], unique: true
  end
end
