require 'rubygems'
require 'mysql'
require 'enumerable_proxy'
require 'readline'

class DbPlot
  attr_reader :string
  attr_accessor :settings
  attr_accessor :data

  def initialize(options)
    @settings = {
      :host => 'localhost',
      :username => 'root',
      :password => 'password',
      :database => ''
    }
    
    %w(host database username password).map.to_sym.each do |setting|
      settings[setting] = options[setting] if options[setting]
    end
  end
  
  def connection
    @connection ||= Mysql.new *%w(host username password database).map{|x| settings[x.to_sym]}
  end
  
  def execute
    if complete?
      if @data = query(substitute)
        puts
        p @data
        puts
        @plot.plot(@data)
      end
      @string = nil
    end
  end
  
  def query(query, args = [])
    st = connection.prepare query
    st.execute *args
    data = []
    st.each {|d| data << d }
    data
  rescue => e
    puts
    puts e.message
    return nil
  end
  
  def parse(string)
    @string = string
    return self
  end

  def parse_line(string)
    return self if string.strip == ""
    @string ||= ""
    @string += " #{string}"
    return self
  end

  def complete?
    @string =~ /;/
  end
  
  def strip_comments
    @string.gsub /#.+$/, ''
  end
  
  def prompt
    @string.nil? ? ' > ' : '  | '
  end
  
  def substitute
    @plot = Plot.new
    strip_comments.gsub("plot", "select")
  end
  
  class Plot
    attr_accessor :options
    def initialize
      @options = {:file => 'dbplot.pdf'}
    end
    
    def plot(data)
      p 'plotting'
      template = %{
        require(ggplot2);
        tempdata <- data.frame(x = c(1,2), y = c(2,5));
        pdf('#{@options[:file]}', width = 11, height = 8.5);
        qplot(x, y, data=tempdata)
        dev.off()
      }
      
      `echo \"#{template}\" | r --no-save`
    end
    
    def method_missing(method, *args)
      raise unless method =~ /=$/
      options[method.gsub(/=$/, '').to_sym] = args.first
    end
  end
end

d = DbPlot.new :database => 'dbplot', :username => 'root', :password => 'password'

if ARGV.join.strip.length > 0
  d.parse_line(ARGV.join).execute
else
  while line = Readline.readline(d.prompt, true)
    case line
    when 'exit' then exit
    when 'help' then puts "here's some help: rtfm\n\n "
    else
      d.parse_line(line).execute
    end
  end
end