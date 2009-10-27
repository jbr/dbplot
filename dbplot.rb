require 'rubygems'
require 'mysql'
require 'enumerable_proxy'
require 'readline'

class DbPlot
  attr_reader :string
  attr_accessor :settings, :debug, :data

  def initialize(options = {})
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
  
  def execute
    return unless complete?
    template = %{
      require(ggplot2);
      require(RMySQL);
      
      con <- dbConnect(MySQL(), user="#{settings[:username]}",
          password="#{settings[:password]}", dbname="#{settings[:database]}",
          host="localhost");
        
        data <- dbGetQuery(con, "#{@query}")
        
        pdf('#{@file}', width = 11, height = 8.5);
        
        qplot(#{@abscissa_alias}, #{@ordinate_alias}, data=data);
        
        dev.off()
      }
    puts template if debug
    `echo \"#{template.gsub('"', '\\"')}\" | r --no-save #{"2>&1 > /dev/null" unless debug}`
  end
  
  def parse
    name_regex = /[a-z_]+/
    
    if string =~ /plot (#{name_regex})(?: as (#{name_regex}))? vs (#{name_regex})(?: as (#{name_regex}))? from (#{name_regex})(?: into ([a-z._]+))?/i
      @ordinate, @ordinate_alias, @abscissa, @abscissa_alias, @table, @file = $1, $2, $3, $4, $5, $6

      @file ||= "out.pdf"

      needed_columns = {@ordinate => @ordinate_alias, @abscissa => @abscissa_alias}
      
      column_string = needed_columns.map do |col, col_alias|
        "#{col}#{" AS #{col_alias}" if col_alias}"
      end.join(",\n")

      @query = %{
        SELECT
          #{column_string}
        FROM #{@table}
      }.strip
    else
      puts "\ncould not parse:\"#{string}\"\n\n"
      @string = nil
    end
    
    return self
  end

  def parse_line(string)
    return self if string.strip == ""
    @string ||= ""
    @string += " #{string}"
    parse if complete?
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
  end
end

d = DbPlot.new

begin
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    opts.on("-v", "--verbose", "Run verbosely") {|v| d.debug = v }
    opts.on("-h", "--host HOST", "MySQL Host") {|h| d.settings[:host] = h }
    opts.on("-u", "--user USER", "MySQL User") {|u| d.settings[:username] = u }
    opts.on("-p", "--password PASSWORD", "MySQL Password") {|p| d.settings[:password] = p }
    opts.on("-d", "--database DATABASE", "MySQL Database") {|db| d.settings[:database] = db }
  end.parse!
rescue => e
  puts e.message
  exit
end
 
if ARGV.join.strip.length > 0
  d.parse_line(ARGV.join + ";")
else
  while line = Readline.readline(d.prompt, true)
    case line
    when /^(exit|quit)$/ then exit
    when 'help' then puts "help message goes here\n\n "
    else d.parse_line(line)
    end
  end
end