require 'cgi'

module BorrowDirect
  # Generate a "deep link" to query results in BD's native
  # HTML interface. 
  class GenerateQuery
    attr_accessor :url_base

    # Hash from our own API argument to BD field code
    @@fields = {
      :keyword  => "term",
      :title    => "ti",
      :author   => "au",
      :subject  => "su",
      :isbn     => "isbn",
      :issn     => "issn"
    }

    def initialize(url_base = nil)
      self.url_base = (url_base || BorrowDirect::Defaults.html_base_url)
    end

    # build_query_with(:title => "one two", :author => "three four")
    # valid keys are those supported by BD HTML interface:
    #     :title, :author, :isbn, :subject, :keyword, :isbn, :issn
    #
    # For now, the value is always searched as a phrase, and multiple
    # fields are always 'and'd.  We may enhance/expand later. 
    #
    # Returns an un-escaped query, still needs to be put into a URL
    def build_query_with(options)
      clauses = []

      options.each_pair do |field, value|
        next if value.nil?

        code = @@fields[field]

        raise ArgumentError.new("Don't recognize field code `#{field}`") unless code

        clauses << %Q{#{code}="#{escape value}"}
      end

      return clauses.join(" and ")
    end



    def query_url_with(arg)
      query = arg.kind_of?(Hash) ? build_query_with(arg) : arg.to_s
      
      return add_query_param(self.url_base, "query", query).to_s
    end

    # Give it a :title and optionally an :author, we'll normalize
    # them to our suggestion for a good BD author-title keyword
    # search. Returns a hash suitable for passing to #query_url_with
    #
    # Additional option :max_title_words, default 5. 
    def normalized_author_title_params(options)
      raise ArgumentError.new("Need a Hash argument, got #{options.inspect}") unless options.kind_of?(Hash)

      # Symbolize keys please
      #options = options.inject({}){ |h, (k, v)| hash.merge( (k.respond_to?(:to_sym) ? k.to_sym : k) => v )  }

      unless options.has_key?(:title) && ! (options[:title].nil? || options[:title].empty?)
        raise ArgumentError.new("Need at least a :title param") 
      end

      title           = options[:title].dup
      author          = options[:author].dup if options[:author]

      # Normalize title in various ways.

      

      # We don't do any normalization to author at present. 
      results = {
        :title => normalized_title(title, :max_title_words => options[:max_title_words])
      }
      results[:author] = author if author && ! author.empty?
      return results
    end

    def normalized_author_title_query(options)
      return self.query_url_with self.normalized_author_title_params(options)
    end

    def normalized_title(title, args = {})
      max_title_words = args[:max_title_words] || 5
 
      # Remove all things in parens at the END of the title, they tend
      # to be weird addendums. 
      title.gsub!(/\([^)]*\)\s*$/, '')

      # Strip the subtitle or other weird titles, just keep the text
      # before the first colon OR semi-colon
      title.sub!(/[\:\;](.*)$/, '')

      # remove any remaining non-alphanumeric, excepting apostrophe, replacing
      # with space. The punctuation doesn't help our queries. 
      title.gsub!(/[^[:alnum:][:space:]\']/, ' ')

      # compress any remaining whitespace
      title.strip!
      title.gsub!(/\s+/, ' ')

      # downcase
      title.downcase!

      # Limit to only first N words
      if max_title_words && title.index(/((.+?[ ,.:\;]+){#{max_title_words}})/)
        title = title.slice(0, $1.length).gsub(/[ ,.:\;]+$/, '')
      end

      return title
    end

    

    # Escape a query value. 
    # We don't really know how to escape, for now
    # we just remove double quotes and parens, and replace with spaces. 
    # those seem to cause problems, and that seems to work. 
    def self.escape(str)
      str.gsub(/[")()]/, ' ')
    end
    # Instance method version for convenience. 
    def escape(str)
      self.class.escape(str)
    end

    def add_query_param(uri, key, value)
      uri = URI.parse(uri) unless uri.kind_of? URI

      query_param = "#{CGI.escape key}=#{CGI.escape value}"

      if uri.query
        uri.query += "&" + query_param
      else
        uri.query = query_param
      end
      
      return uri
    end


  end
end