class InitialSchema < ActiveRecord::Migration
  def change
    create_table :books do |t|
      t.string :title
      t.integer :review_count
      t.float :average_rating
      t.string :book_url
      t.string :book_cover_image
      t.text :notes
      
      t.timestamps
    end
    
    create_table :authors do |t|
      t.string :name
    end
    
    create_table :tags do |t|
      t.string :name
    end
    
    create_table :authors_books, id: false do |t|
      t.belongs_to :author, index: true
      t.belongs_to :book, index: true
    end
    
    create_table :books_tags, id: false do |t|
      t.belongs_to :book, index: true
      t.belongs_to :tag, index: true
    end
    
  end
end
