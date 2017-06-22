require 'sinatra'
require 'sinatra/cross_origin'
require "sinatra/activerecord"

require 'nokogiri'
gem 'http'
require 'http'

require 'sqlite3'

class Book < ActiveRecord::Base
  has_and_belongs_to_many :authors
  has_and_belongs_to_many :tags
  
  def api_hash
    return {
      id: self.id,
      title: self.title,
      averageRating: self.average_rating,
      reviewCount: self.review_count,
      bookUrl: self.book_url,
      bookCoverImage: self.book_cover_image,
      notes: self.notes,
      tags: self.tags.collect { |t| t.api_hash },
      authors: self.authors.collect { |a| a.api_hash }
    }  
  end
end

class Author < ActiveRecord::Base
  has_and_belongs_to_many :books
  
  def api_hash
    return {
      id: id,
      name: name
    }
  end
end

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :books

  def api_hash
    return {
      id: id,
      name: name,
      bookCount: books.count
    }
  end
end



class JuliaAPI < Sinatra::Base
  register Sinatra::CrossOrigin
  register Sinatra::ActiveRecordExtension

  set :database, {adapter: "sqlite3", database: "books.sqlite3"}

  configure do
    enable :cross_origin
    enable :logging
  end
  
  
  post '/books' do 
	  puts params.inspect
	  
	  
	  #output = ""
	  #params.each do |key, value|
		#  output << "<strong style='color: red'>#{key}</strong>: #{value} <br>"
		#end

    # redirect 'http://julia.rogue.is/api-test'
		# otherwise browser would interpret information as html
		#content_type :html
    
    book_data = params.to_json
    
    p = params
    
    book_authors = []
    
    authors = params[:authors]
    
    unless authors.nil?
      authors = authors.strip.split(/,[ ]+/)
      
      authors.each do |name|
        existing = Author.where(name: name)
        if existing.empty?
          a = Author.new
          a.name = name
          a.save
          book_authors << a
        else
          book_authors << existing.first
        end
      end
    end
    
    
    book_tags = []
    
    tags = params[:tags]
    
    unless tags.nil?
      tags = tags.strip.split(/,[ ]+/)
      
      tags.each do |name|
        existing = Tag.where(name: name)
        if existing.empty?
          t = Tag.new
          t.name = name
          t.save
          
          book_tags << t
        else
          book_tags << existing[0]
        end
      end
    end
    
        
    
    b = Book.new
    b.title = p[:title]
    b.review_count = p[:reviewCount]
    b.average_rating = p[:averageRating].to_f
    b.book_url = p[:bookUrl]
    b.book_cover_image = p[:bookCoverImage]
    b.notes = p[:notes]
    b.authors = book_authors
    b.tags = book_tags
    b.save
    
		redirect "http://julia.rogue.is/amazon-book-wishlist"
	end
	
  get '/tags' do
    content_type :json
    Tag.all.collect { |t| t.api_hash }.sort_by { |t| t[:bookCount] }.to_json
  end

	get '/books' do
	  books = []

	  if params[:sortBy] 
		  sort_by = params[:sortBy]
		else 
			sort_by = "averageRating"
		end 
		if params[:direction]
			direction = params[:direction]
		else 
			direction = "desc" 
		end 
		
	  
	  #File.foreach("books.db") do |line|
	  #  books << JSON::parse(line)
	  #end
	  if params[:q]
#   	  $db.execute( "select * from books where title like '%" + params[:q] + "%'") do |row|
#         row.keys.each { |key| row.delete(key) if key.kind_of?(Fixnum) }
#   
#         books << row
#       end
    elsif params[:tag]
      t = Tag.find_by_name(params[:tag])
      if t.nil?
        return [].to_json
      else
        t.books.each do |b|
          books << b.api_hash
        end
      end
      
    else
      Book.all.each do |b|
        books << b.api_hash
      end
    end
		content_type :json
	  return JSON::pretty_generate(books)
  end
  
  post '/books/delete' do
	  if params[:id]
		  b = Book.find_by_id(params[:id])
		  b.destroy unless b.nil?
		end
		return
	end

	
  get '/get-amazon-data' do
		content_type :json

		data = {}
	  
	  url = params[:url]

		if url.nil?
			data[:error] = '===ERROR===You must provide a URL'
			return data.to_json
		else 
			data[:bookUrl] = url
			puts "===COMMENT=== bookUrl=#{data[:bookUrl]}"
		end

	  res = HTTP.get(url)
	  body = res.body.to_s
	  
    # Regular Expressions stuff
	  title_re = /<span id="productTitle" class="a-size-large">(.*)<\/span>/
	  ebook_title_re = /<span id="ebooksProductTitle" class="a-size-extra-large">(.*)<\/span>/
	  
	  # If Amazon book is an Ebook, id 'productTitle' does not work.
	  # Need to use id 'ebooksProductTitle' instead.
	  title = title_re.match(body)
	  if title.nil?
		  title = ebook_title_re.match(body)
		end
		
		puts "TITLE: #{title.inspect}"

	  if title.nil?
			data['error'] = "Could not find title"		  
	  else
      data[:title] = title[1]
		end
		
		if body.index("a-icon-kindle-unlimited")
		  puts "===COMMENT===REG EXP. Kindle Unlimited True"
			data[:kindleUnlimited] = true
		else 
			data[:kindleUnlimited] = false
		end
		
		
		#===Nokogiri stuff===
		doc = Nokogiri::HTML(body)
		authors = []
		
		doc.css("span.author.notFaded a.a-link-normal.contributorNameID").each do |author|
			authors << author.content
		end 
		
		#puts "Looking for kindleUnlimited image..."
# 		unless data[:kindleUnlimited]
#   		doc.css("li.swatchElement a.a-button-text img").each do |k|
#   			puts "===COMMENT=== NOKOGIRI kindleUnlimited= true (#{data[:title]})"
#   			data[:kindleUnlimited] = true
#   		end
#     end
		
		if data[:kindleUnlimited]
			data[:kindlePrice] = 0.00
		else 
			kindlePrice = doc.css("li.swatchElement span.a-size-base.a-color-price").first.content.strip.sub("$","").to_f
			data[:kindlePrice] = kindlePrice
		end

    # puts "===COMMENT=== kindlePrice= #{data[:kindlePrice]} (#{data[:title]})" 
		
		if authors.empty?
			doc.css("span.author.notFaded a.a-link-normal").each do |author|
				authors << author.content
			end
		end
		
		data[:authors] = authors
		
		tags = []
		doc.css("ul.zg_hrsr").each do |list|
			list.css("li span.zg_hrsr_ladder a").each do |tag|
				tags << tag.content unless ["Books", "Kindle Store", "Kindle eBooks"].include?(tag.content)
			end
		end
		
		data[:tags] = tags.uniq
		reviewCount = doc.css("span.totalReviewCount")
# 		puts reviewCount.inspect
		data[:reviewCount] = reviewCount.empty? ? "0" : reviewCount.first.content
# 		puts data[:reviewCount]
		averageRating = doc.css("span.arp-rating-out-of-text")
		data[:averageRating] = averageRating.empty? ? "N/A" : averageRating.first.content.split(" ").first
    # fiveStarPercentage = doc.css("td a.histogram-review-count[class~='5star']").first.content.sub("%","").to_f/100
    # data[:fiveStarPercentage] = fiveStarPercentage.empty? ? "None" : fiveStarPercentage.first.content.sub("%","").to_f/100
		
		front_image = doc.css("img.frontImage")
		
		#puts front_image.inspect
		#puts front_image.first.inspect
		img_data = JSON::parse(front_image.first.attribute("data-a-dynamic-image"))
		
		
		data[:bookCoverImage] = img_data.keys.first
		
# 		data[:authorImage] = doc.css("div.authorImageBlock img").first.attribute("src")
# 		puts "===COMMENT===AUTHOR IMG = #{data[:authorImage]}"
		

# 		puts JSON::pretty_generate(data)
		return data.to_json
  end

end