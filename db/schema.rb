# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170622184813) do

  create_table "authors", force: :cascade do |t|
    t.string "name"
  end

  create_table "authors_books", id: false, force: :cascade do |t|
    t.integer "author_id"
    t.integer "book_id"
  end

  add_index "authors_books", ["author_id"], name: "index_authors_books_on_author_id"
  add_index "authors_books", ["book_id"], name: "index_authors_books_on_book_id"

  create_table "books", force: :cascade do |t|
    t.string   "title"
    t.integer  "review_count"
    t.float    "average_rating"
    t.string   "book_url"
    t.string   "book_cover_image"
    t.text     "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "books_tags", id: false, force: :cascade do |t|
    t.integer "book_id"
    t.integer "tag_id"
  end

  add_index "books_tags", ["book_id"], name: "index_books_tags_on_book_id"
  add_index "books_tags", ["tag_id"], name: "index_books_tags_on_tag_id"

  create_table "tags", force: :cascade do |t|
    t.string "name"
  end

end
