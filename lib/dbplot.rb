require 'rubygems'
require 'mysql'
require 'enumerable_proxy'
require 'readline'
require 'erb'

class DbPlot
  attr_accessor :settings, :debug, :data, :string

  def self.version
    "DbPlot v" + version_string
  end
    
  def settings
    @settings ||= {
      :host => 'localhost',
      :username => 'root',
      :password => 'password',
      :database => '',
      :width => 5,
      :height => 5
    }
  end

  def initialize(options = {})
    %w(host database username password).map.to_sym.each do |setting|
      settings[setting] = options[setting] if options[setting]
    end
  end
  
  def template_file
    settings[:template_file] || File.instance_eval {expand_path(join(dirname(__FILE__), 'dbplot', 'template.r.erb'))}
  end
  
  def execute
    return unless complete?
    
    @query = %{SELECT #{select_string} FROM #{@table}}
    
    template = ERB.new(File.read(template_file)).result(binding)
    
    puts template if debug
    
    unless settings[:dry_run]
      `echo \"#{template.gsub('"', '\\"')}\" | r --no-save #{"2>&1 > /dev/null" unless debug}`
    end
    @string = nil
  end

  def parse
    if legal_expression?
      set_defaults
      set_file
      set_color_by
      set_facet_by
    else
      puts "\ncould not parse: \"#{string}\"\n\n"
      @string = nil
    end
    
    self
  end

  def parse_line(string)
    return self if string.strip == ""
    @string ||= ""
    @string += " #{string}"
    parse if complete?
    return self
  end

  def complete?
    @string =~ /;\s*$/
  end
  
  private
  
  def select_string
    @needed_columns.map do |col, col_alias|
      "#{col}#{" AS #{col_alias}" if col_alias}"
    end.join(", ")
  end
  
  def legal_expression?
    name_regex = /[a-z_]+/
    
    if string =~ /plot (#{name_regex})(?: as (#{name_regex}))? vs (#{name_regex})(?: as (#{name_regex}))? from (#{name_regex})/i
      @ordinate, @ordinate_alias, @abscissa, @abscissa_alias, @table = $1, $2, $3, $4, $5
      true
    end
  end
  
  def set_file
    if string =~ /into ([a-z._]+.pdf)/
      @file = $1
    else
      @file = "out.pdf"
    end
  end
  
  def set_defaults
    @needed_columns = {@ordinate => @ordinate_alias, @abscissa => @abscissa_alias}
    
    @qplot = [
      @abscissa_alias || @abscissa,
      @ordinate_alias || @ordinate
    ]
  end
  
  def set_color_by
    name_regex = /[a-z_]+/
  
    if string =~ /color by (#{name_regex})(?: as (#{name_regex}))?/i
      @needed_columns[$1] = $2
      @qplot << "colour = #{$2 || $1}"
    end
  end
  
  def set_facet_by
    name_regex = /[a-z_]+/
    
    if string =~ /facet by (#{name_regex})(?: as (#{name_regex}))?(?: vs (#{name_regex})(?: as (#{name_regex}))?)?/i
      @needed_columns[$1] = $2
      if $3
        @needed_columns[$3] = $4
        @qplot << "facets = #{$2 || $1}~#{$4 || $3}"
      else
        @qplot << "facets = ~#{$2 || $1}"
      end
    end
  end
  
  def strip_comments
    @string.gsub /#.+$/, ''
  end
  
  def prompt
    @string.nil? ? 'dbplot> ' : '     -> '
  end
  
  def self.version_string
    File.instance_eval { read(expand_path(join(dirname(__FILE__), '..', "VERSION"))) }
  end
end