require 'sinatra'
require 'sinatra/cross_origin'
require 'nokogiri'
gem 'http'
require 'http'

require 'sqlite3'


if !File.exists?("books.db")
  $db = SQLite3::Database.new "books.db"
  
  # Create a table
  rows = $db.execute("
    create table books (
      id integer primary key autoincrement,
      title varchar(255),
      reviewCount integer,
      averageRating varchar(10),
      authors varchar(255),
      bookUrl varachar(255),
      bookCoverImage varachar(255),
      tags varachar(255),
      notes text
    );
  ");
  puts rows.inspect
else
  $db = SQLite3::Database.new "books.db"
end  

$db.results_as_hash = true



class JuliaAPI < Sinatra::Base
  register Sinatra::CrossOrigin

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
    
    $db.execute("INSERT INTO books (title, reviewCount, averageRating, authors, bookUrl, bookCoverImage, tags, notes) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)", [p[:title], p[:reviewCount], p[:averageRating], p[:authors], p[:bookUrl], p[:bookCoverImage], p[:tags], p[:notes]])


    #File.open('books.db', 'a') do |f|
    #  f.puts(book_data)
    #end
# 		content_type :json
# 		
# 		return book_data
		redirect "http://julia.rogue.is/amazon-book-wishlist"
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
  	  $db.execute( "select * from books where title like '%" + params[:q] + "%'") do |row|
        row.keys.each { |key| row.delete(key) if key.kind_of?(Fixnum) }
  
        books << row
      end
    else
  	  $db.execute( "select * from books order by #{sort_by} #{direction}" ) do |row|
        row.keys.each { |key| row.delete(key) if key.kind_of?(Fixnum) }
        books << row
      end
    end
		content_type :json
	  return JSON::pretty_generate(books)
  end
  
  post '/books/delete' do
	  if params[:id]
		  $db.execute("delete from books where id = ?", params[:id])
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
		
		data[:bookCoverImage] = doc.css("img.frontImage").first.attribute("src")
		
# 		data[:authorImage] = doc.css("div.authorImageBlock img").first.attribute("src")
# 		puts "===COMMENT===AUTHOR IMG = #{data[:authorImage]}"
		

# 		puts JSON::pretty_generate(data)
		return data.to_json
  end

end