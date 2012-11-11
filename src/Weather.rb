#!/usr/bin/ruby
#

# = Standard Libraries
require 'optparse'
require 'ostruct'
require 'yaml'
require 'psych'
require 'pp'
require 'open-uri'
require 'timeout'
require 'oj'

# @fn           module Weather # {{{
# @brief        Weather Module
module Weather

  # @fn         class Atmosphere # {{{
  # @brief      Atmosphere handling class
  class Atmosphere

    # @fn        def initialize options # {{{
    # @brief     Default constructor for the Atmosphere class
    def initialize options = nil
      @options                    = options

      unless( options.nil? ) # {{{
        @config_class               = Weather::Config.new( @options.config_filename )
        @config                     = @config_class.content

        @logger                     = Weather::Logger.new( @options )

        @logger.message( :success, "Starting #{__FILE__} run" )
        @logger.message( :info, "Colorizing output as requested" ) if( @options.colorize )

        ####
        #
        # Main Control Flow
        #
        ##########

        @communication              = Weather::Communication.new( @config )
        @cache                      = Cache.new
        @result                     = nil

        if( @cache.cached? and @cache.valid? )
          @logger.message( :info, "Cache available and valid" )
          @result                   = @cache.load_cache
        else

          if( online? )
            @logger.message( :info, "Cache not available and/or not valid" )
            @result                   = OpenStruct.new
            @result.datetime          = DateTime.now.to_s
            @result.conditions        = @communication.conditions
            @result.forecast          = @communication.forecast

            @cache.save_cache( @result )
          else
            @logger.message( :error, "We are not online, cannot call Weather API" )
            exit
          end # of if( online? )

        end # of if( @cache.cached? and @cache.valid? )

        display( @result )

        @logger.message( :success, "Finished #{__FILE__} run" )
      end # of unless( options.nil? ) }}}

    end # of initialize }}}

    # @fn        def display result = "" # {{{
    # @brief     Display result
    def display result = ""
      conditions  = result.conditions
      forecast    = result.forecast

      # Conditions
      cd                = conditions[ "current_observation" ]
      location          = conditions[ "current_observation" ][ "display_location" ][ "city" ]
      weather_now       = cd[ "weather" ]
      weather_temp      = cd[ "temp_c" ]
      weather_humidity  = cd[ "relative_humidity" ]


      # forecast
      fc          = forecast[ "forecast" ]
      fc_day      = fc[ "txt_forecast" ][ "forecastday" ]
      days        = 2 * 2 # 2 days * 2 entries (day + night)

      # interesting fields:
      #
      #    "icon": "cloudy",
      #    "icon_url": "http://icons-ak.wxug.com/i/c/k/cloudy.gif",
      #    "title": "Sunday",
      #    "fcttext": "Overcast with a chance of rain in the afternoon. High of 63F. Winds from the North at 5 to 10 mph shifting to the East in the afternoon. Chance of rain 20%.",
      #    "fcttext_metric": "Overcast with a chance of rain in the afternoon. High of 17C. Winds from the North at 10 to 15 km/h shifting to the East in the afternoon.",
      content     = fc_day[ 0, days ]

      # Printout
      puts "Where:    #{location.to_s}"
      puts "Current:  #{weather_now.to_s} - #{weather_temp.to_s} Degrees C - #{weather_humidity.to_s} Humidity"
      puts ""

      puts "Forecast"
      puts ""
      content.each do |hash|
        period, icon, icon_url, title, fcttext, fcttext_metric, pop = hash["period"], hash["icon"], hash["icon_url"], hash["title"], hash["fcttext"], hash["fcttext_metric"], hash["pop"]
        short_description = fcttext.split(".").first
        icon_description  = icon

        printf( "%-15s (%-15s)    %s\n", title, icon_description, short_description )

      end

    end # }}}

    # @fn        def online? # {{{
    # @brief     Check if we are online
    def online?

      ping_count    = 1
      server        = "www.google.com"
      result        = `ping -q -c #{ping_count} #{server}`
      online        = false

      if( $?.exitstatus == 0 )
        online      = true
      end

      return online
    end # }}}

    # @fn        def parse_cmd_arguments( args ) # {{{
    # @brief     The function 'parse_cmd_arguments' takes a number of arbitrary commandline arguments and parses them into a proper data structure via optparse
    #
    # @param     [STDIN]       args    Ruby's STDIN.ARGS from commandline
    #
    # @return    [OpenStruct]          Ruby optparse package options ostruct object
    def parse_cmd_arguments args

      raise ArgumentError, "Argument provided cannot be empty" if( (args == "") or (args.nil?) )

      options                               = OpenStruct.new

      # Define default options
      options.colorize                      = false
      options.debug                         = false
      options.quiet                         = false

      options.config_filename               = ENV["HOME"] + "/.weatherrc"

      pristine_options        = options.dup

      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{__FILE__.to_s} [options]"

        opts.separator ""
        opts.separator "General options:"

        opts.on("-c", "--config FILENAME", "Use this file as config") do |config|
          options.config_filename = config
        end

        opts.separator ""
        opts.separator "Specific options:"

        opts.on("-q", "--quiet", "Run quietly, don't output much") do |quiet|
          options.quiet = quiet
        end

        opts.on( "--debug", "Print verbose output and more debugging") do |debug|
          options.debug = debug
        end

        opts.separator ""
        opts.separator "Common options:"

        opts.on("-c", "--colorize", "Colorizes the output of the script for easier reading") do |colorize|
          options.colorize = colorize
        end

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end

        # Another typical switch to print the version.
        opts.on_tail("--version", "Show version") do
          puts OptionParser::Version.join('.')
          exit
        end
      end

      opts.parse!(args)

      options
    end # of parse_cmd_arguments }}}

  end # of class Atmosphere }}}

  # @fn         class Cache # {{{
  # @brief      Handles caching
  class Cache

    # @fn       def initialize filename = "/tmp/weather_app_cache.tmp" # {{{
    # @brief    Default constructor
    def initialize filename = "/tmp/weather_app_cache.tmp"
      @valid_time_seconds     = 60 * 60   # 60s * 60min = 1 hour
      @filename               = filename
    end # }}}

    # @fn       def save_cache filename = @filename # {{{
    # @brief    Saves cache from file
    def save_cache content = nil, filename = @filename
      File.open( filename, "w+" ) { |f| Marshal.dump( content, f ) }
    end # of def load_cache # }}}

    # @fn       def load_cache filename = @filename # {{{
    # @brief    Loads cache from file
    def load_cache filename = @filename
      result = nil
      File.open( filename ) { |f| result = Marshal.load( f ) }

      return result
    end # of def load_cache # }}}

    # @fn       def valid? filename = @filename # {{{
    # @brief    Checks if cache is expired or not
    def valid? filename = @filename, valid_time_seconds = @valid_time_seconds
      now                     = DateTime.now.strftime( "%s" ).to_i
      file_time               = DateTime.parse( File.stat( filename ).mtime.to_s ).strftime("%s").to_i
      valid_until_time        = file_time + valid_time_seconds
      response                = false

      if( now >= valid_until_time )
        response              = false
      else
        response              = true
      end

      response
    end # of def valid? # }}}

    # @fn       def cached? filename = @filename # {{{
    def cached? filename = @filename
      File.exist?( filename )
    end # }}}

  end # of class Cache # }}}

  # @fn         class Config # {{{
  # @brief      Handles config file
  class Config

    # @fn       def initialize options # {{{
    # @brief    Default constructor for the Config class
    def initialize filename = ENV["HOME"] + "/.weatherrc"
      @filename = filename
      @content  = read_config
    end # of def initialize # }}}

    # @fn       def read_config filename # {{{
    # @brief    Reads a yaml config describing the stream
    #
    # @param    [String]      filename    String, representing the filename and path to the config file
    # @returns  [OpenStruct]              Returns an openstruct containing the contents of the YAML read config file (uses the feature of Extension.rb)
    def read_config filename = @filename

      # Pre-condition check
      raise ArgumentError, "Filename argument should be of type string, but it is (#{filename.class.to_s})" unless( filename.is_a?(String) )

      # Main
      if( File.exists?( filename ) )
        result = File.open( filename, "r" ) { |file| YAML.load( file ) }                 # return proc which is in this case a hash
        result = hashes_to_ostruct( result ) 
      else
        puts "The config (yaml) file #{filename.to_s} does not exist."
        puts "Either call the application and specify a proper config file via --config or create a config under #{filename.to_s}."
        puts ""
        puts "Here is a config file example:"
        puts ""
        puts "---"
        puts ""
        puts "# Wunderground Weather API ( http://www.wunderground.com/weather/api/ )"
        puts "wunderground_api_key: 00000000000000000"
        puts "city: Tokyo"
        puts ""
        exit
      end

      # Post-condition check
      raise ArgumentError, "The function should return an OpenStruct, but instead returns a (#{result.class.to_s})" unless( result.is_a?( OpenStruct ) )

      result
    end # }}}

    # @fn       def hashes_to_ostruct object # {{{
    # @brief    This function turns a nested hash into a nested open struct
    #
    # @author   Dave Dribin
    # Reference: http://www.dribin.org/dave/blog/archives/2006/11/17/hashes_to_ostruct/
    #
    # @param    [Object]    object    Value can either be of type Hash or Array, if other then it is returned and not changed
    # @returns  [OStruct]             Returns nested open structs
    def hashes_to_ostruct object

      return case object
      when Hash
        object = object.clone
        object.each { |key, value| object[key] = hashes_to_ostruct(value) }
        OpenStruct.new( object )
      when Array
        object = object.clone
        object.map! { |i| hashes_to_ostruct(i) }
      else
        object
      end

    end # of def hashes_to_ostruct }}}

    attr_reader :content

  end # of class Config # }}}

  # @fn         class Communication # {{{
  # @brief      Handles communication with the weather API
  class Communication

    # @fn       def initialize options # {{{
    # @brief    Default constructor for the Communication class
    def initialize config = nil
      raise ArgumentError, "Config file cannot be nil" if( config.nil? )

      @config     = config
      @key        = @config.wunderground_api_key
      @city       = @config.city + ".json"

      @baseURL    = "http://api.wunderground.com/api"
      @conditions = @baseURL + "/" + @key + "/conditions/q/"
      @forecast   = @baseURL + "/" + @key + "/forecast/q/"
    end # of def initialize # }}}

    # @fn       def conditions city = @city, url = @conditions # {{{
    def conditions city = @city, url = @conditions
      raise ArgumentError, "City cannot be nil" if( city.nil? )

      city        = city + ".json" unless( city =~ %r{.json}i )
      uri         = url + city
      content     = get( uri )
      response    = ""

      unless( content.nil? )
        response  = Oj.load( content )
      end

      return response
    end # }}}

    # @fn       def forecast city = @city, url = @forecast # {{{
    def forecast city = @city, url = @forecast
      raise ArgumentError, "City cannot be nil" if( city.nil? )

      city      = city + ".json" unless( city =~ %r{.json}i )
      uri       = url + city
      content   = get( uri )

      unless( content.nil? )
        response  = Oj.load( content )
      end

      return response
    end # }}}

    # @fn       def get url # {{{
    # @brief    The function get retrieves the given URL content and returns it to the caller
    #
    # @param    [String]      url     Requires a string containing a uri which will be downloaded.
    #
    # @returns  [Oj]          Returns an Oj object
    def get url
      # Pre-condition
      raise ArgumentError, "The function expects a string, but got a (#{url.class.to_s})" unless( url.is_a?(String) )

      # Main
      request                       = nil

      begin
        # wait 5s
        status = Timeout::timeout(6) {
          request                       = open( url, "r", :read_timeout => nil )
        }
      rescue Timeout::Error
        puts 'Time out error - That took too long, exiting...'
        exit
      end

      return request
    end # }}}

  end # of class Communication # }}}

  # @fn         class Logger # {{{
  # @brief      Logger class handling the log output
  class Logger

    # @fn           def initialize options = nil # {{{
    # @brief        Constructor for the Logger class
    def initialize options = nil

      # Input sanity check # {{{
      # raise ArgumentError, "Options cannot be nil" if( options.nil? )

      # Set some sensible default
      if( options.nil? )
        options = OpenStruct.new
        options.colorize = true
        options.quiet    = false
      end

      raise ArgumentError, "Options must be of type OpenStruct" unless( options.is_a?( OpenStruct ) )
      # }}}

      @options = options
    end  # }}}

    # @fn     def colorize color, message # {{{
    # @brief  The function colorize takes a message and wraps it into standard color commands such as for baih.
    #
    # @param  [String] color   The colorname in plain english. e.g. "LightGray", "Gray", "Red", "BrightRed"
    # @param  [String] message The message which should be wrapped
    #
    # @return [String] Colorized message string
    #
    # @note   This might not work for your particular terminal. Sometimes "\033" is needed as escape.
    #
    # Black       0;30     Dark Gray     1;30
    # Blue        0;34     Light Blue    1;34
    # Green       0;32     Light Green   1;32
    # Cyan        0;36     Light Cyan    1;36
    # Red         0;31     Light Red     1;31
    # Purple      0;35     Light Purple  1;35
    # Brown       0;33     Yellow        1;33
    # Light Gray  0;37     White         1;37
    def colorize color, message 

      colors  = {
        "Gray"        => "\e[1;30m",
        "LightGray"   => "\e[0;37m",
        "Cyan"        => "\e[0;36m",
        "LightCyan"   => "\e[1;36m",
        "Blue"        => "\e[0;34m",
        "LightBlue"   => "\e[1;34m",
        "Green"       => "\e[0;32m",
        "LightGreen"  => "\e[1;32m",
        "Red"         => "\e[0;31m",
        "LightRed"    => "\e[1;31m",
        "Purple"      => "\e[0;35m",
        "LightPurple" => "\e[1;35m",
        "Brown"       => "\e[0;33m",
        "Yellow"      => "\e[1;33m",
        "White"       => "\e[1;37m",
        "NoColor"     => "\e[0m"
      }

      raise ArgumentError, "Function arguments cannot be nil" if( color.nil? or message.nil? )
      raise ArgumentError, "Unknown color" unless( colors.keys.include?( color ) )

      colors[ color ] + message + colors[ "NoColor" ]
    end # of def colorize }}}

    # @fn     def message level, msg, colorize = @options.colorize # {{{
    # @brief  The function message will take a message as argument as well as a level (e.g. "info", "ok", "error", "question", "debug") which then would print 
    #         ( "(--) msg..", "(II) msg..", "(EE) msg..", "(??) msg..")
    # @param  [Symbol] level Ruby symbol, can either be :info, :success, :error or :question
    # @param  [String] msg String, which represents the message you want to send to stdout (info, ok, question) stderr (error)
    #
    # Helpers: colorize
    def message level, msg, colorize = @options.colorize

      # Input verification {{{
      raise ArgumentError, "Level can't be nil" if( level.nil? )
      raise ArgumentError, "Message can't be nil" if( msg.nil? )
      raise ArgumentError, "Coloize can't be nil" if( colorize.nil? )
      # }}}

      symbols = {
        :info      => [ "(--)", "Brown"       ],
        :success   => [ "(II)", "LightGreen"  ],
        :warning   => [ "(WW)", "Yellow"      ],
        :error     => [ "(EE)", "LightRed"    ],
        :question  => [ "(??)", "LightCyan"   ],
        :debug     => [ "(++)", "LightBlue"   ]
      }

      raise ArugmentError, "Can't find the corresponding symbol for this message level (#{level.to_s}) - is the spelling wrong?" unless( symbols.key?( level )  )

      print = []

      output = ( level == :error ) ? ( "STDERR.puts" ) : ( "STDOUT.puts" )
      print << output
      print << "colorize(" if( colorize )
      print << "\"" + symbols[ level ].last + "\"," if( colorize )
      print << "\"#{symbols[ level ].first.to_s} #{msg.to_s}\""
      print << ")" if( colorize )

      print.clear if( @options.quiet )

      eval( print.join( " " ) )

    end # of def message }}}

  end # of class Logger }}}

end # of module Weather }}}


# = Direct Invocation
if __FILE__ == $0 # {{{
  options = Weather::Atmosphere.new.parse_cmd_arguments( ARGV )
  app     = Weather::Atmosphere.new( options )
end # of if __FILE__ == $0 # }}}


# vim:ts=2:tw=100:wm=100
