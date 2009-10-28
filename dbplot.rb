require 'rubygems'
require 'mysql'
require 'enumerable_proxy'
require 'readline'

class DbPlot
  attr_accessor :settings, :debug, :data, :string

  def self.version
    "DbPlot v" + File.instance_eval { read(join(dirname(__FILE__), "VERSION")) }
  end

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
    
    column_string = @needed_columns.map do |col, col_alias|
      "#{col}#{" AS #{col_alias}" if col_alias}"
    end.join(", ")
    
    @query = %{SELECT #{column_string} FROM #{@table}}
    
    template = %{
      require(ggplot2);
      require(RMySQL);
      
      con <- dbConnect(MySQL(), user="#{settings[:username]}",
          password="#{settings[:password]}", dbname="#{settings[:database]}",
          host="localhost");
        
        data <- dbGetQuery(con, "#{@query}")
        
        pdf('#{@file}', width = 11, height = 8.5);
        
        qplot(#{@qplot.join(", ")}, data=data);
        
        dev.off()
      }
    puts template if debug
    unless settings[:dry_run]
      `echo \"#{template.gsub('"', '\\"')}\" | r --no-save #{"2>&1 > /dev/null" unless debug}`
    end
  end
  
  def parse
    name_regex = /[a-z_]+/
    
    if string =~ /plot (#{name_regex})(?: as (#{name_regex}))? vs (#{name_regex})(?: as (#{name_regex}))? from (#{name_regex})(?: into ([a-z._]+))?/i
      @ordinate, @ordinate_alias, @abscissa, @abscissa_alias, @table, @file = $1, $2, $3, $4, $5, $6

      @file ||= "out.pdf"

      @needed_columns = {@ordinate => @ordinate_alias, @abscissa => @abscissa_alias}
      
      @qplot = [
        @abscissa_alias || @abscissa,
        @ordinate_alias || @ordinate
      ]
      
      if string =~ /color by (#{name_regex})(?: as (#{name_regex}))?/i
        @needed_columns[$1] = $2
        @qplot << "colour = #{$2 || $1}"
      end
    else
      puts "\ncould not parse: \"#{string}\"\n\n"
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
    @string.nil? ? 'dbplot> ' : '     -> '
  end
  
  def substitute
  end
end

d = DbPlot.new

begin
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    opts.instance_eval do
      on("--help", "This message") {puts opts; exit}
      on("-v", "--verbose", "Run verbosely") {|v| d.debug = !!v }
      on("-h", "--host HOST", "MySQL Host") {|h| d.settings[:host] = h }
      on("-u", "--user USER", "MySQL User") {|u| d.settings[:username] = u }
      on("-p", "--password PASSWORD", "MySQL Password") {|p| d.settings[:password] = p }
      on("-d", "--database DATABASE", "MySQL Database") {|db| d.settings[:database] = db }
      on("-q", "--query QUERY", "dbplot query") {|q| d.string = q.gsub(/;?$/, ";") }
      on("--version", "Print version info and exit") {puts DbPlot.version;exit}
      on "--dry-run", "Print but do not execute. Implies -v." do |dry|
        d.debug = d.settings[:dry_run] = true
      end
    end
  end.parse!
rescue => e
  puts e.message
  exit
end

if d.complete?
  d.parse.execute
else
  while line = Readline.readline(d.prompt, true)
    case line
    when /^(exit|quit)$/ then exit
    when 'help' then puts "help message goes here\n\n "
    else d.parse_line(line)
    end
  end
end