class DbPlot
  module Runner
    def self.start
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
            on("--width WIDTH", "pdf width") {|w| d.settings[:width] = w}
            on("--height HEIGHT", "pdf height") {|w| d.settings[:height] = h}
            on("--template TEMPLATE_FILE", "use alternate template") do |t|
              d.settings[:template_file] = t
            end
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
          else d.parse_line(line).execute
          end
        end
      end
    end
  end
end