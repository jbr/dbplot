require 'rubygems'
require 'mysql'
require 'enumerable_proxy'
require 'readline'

class DbPlot
  attr_reader :string, :debug
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
    
    if string =~ /plot (#{name_regex})(?: as (#{name_regex})) vs (#{name_regex})(?: as (#{name_regex})) from (#{name_regex})(?: into ([a-z._]+))?/i
      @ordinate, @ordinate_alias, @abscissa, @abscissa_alias, @table, @file = $1, $2, $3, $4, $5, $6
      @ordinate_alias ||= @ordinate
      @abscissa_alias ||= @abscissa
      @file ||= "out.pdf"
      @query = %{
        SELECT
          #{@ordinate} AS #{@ordinate_alias},
          #{@abscissa} AS #{@abscissa_alias}
        FROM #{@table}
      }.strip
    else
      raise "did not compute"
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

d = DbPlot.new :database => 'dbplot', :username => 'root', :password => 'password'

if ARGV.join.strip.length > 0
  d.parse_line(ARGV.join + ";")
else
  while line = Readline.readline(d.prompt, true)
    case line
    when 'exit' then exit
    when 'help' then puts "here's some help: rtfm\n\n "
    else
      d.parse_line(line)
    end
  end
end