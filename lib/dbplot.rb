require 'rubygems'
require 'mysql'
require 'enumerable_proxy'
require 'readline'

class DbPlot
  attr_accessor :settings, :debug, :data, :string

  def self.version
    "DbPlot v" + File.instance_eval { read(expand_path(join(dirname(__FILE__), '..', "VERSION"))) }
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
          host="#{settings[:host]}");
        
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
    
    if string =~ /plot (#{name_regex})(?: as (#{name_regex}))? vs (#{name_regex})(?: as (#{name_regex}))? from (#{name_regex})/i
      @ordinate, @ordinate_alias, @abscissa, @abscissa_alias, @table = $1, $2, $3, $4, $5

      @file = "out.pdf"
      
      @needed_columns = {@ordinate => @ordinate_alias, @abscissa => @abscissa_alias}
      
      @qplot = [
        @abscissa_alias || @abscissa,
        @ordinate_alias || @ordinate
      ]
      
      if string =~ /into ([a-z._]+.pdf)/
        @file = $1
      end
      
      if string =~ /color by (#{name_regex})(?: as (#{name_regex}))?/i
        @needed_columns[$1] = $2
        @qplot << "colour = #{$2 || $1}"
      end
      
      if string =~ /facet by (#{name_regex})(?: as (#{name_regex}))?(?: vs (#{name_regex})(?: as (#{name_regex}))?)?/i
        @needed_columns[$1] = $2
        if $3
          @needed_columns[$3] = $4
          @qplot << "facets = #{$2 || $1}~#{$4 || $3}"
        else
          @qplot << "facets = ~#{$2 || $1}"
        end
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
end