#!/usr/bin/ruby
#

# = Standard Libraries
require 'optparse'
require 'ostruct'


# @fn           module Weather # {{{
# @brief        Weather Module
module Weather

  # @fn         class Atmosphere # {{{
  # @brief      Atmosphere handling class
  class Atmosphere

    # @fn       def initialize options # {{{
    # @brief    Default constructor for the Atmosphere class
    def initialize options = nil
      @options                    = options

      @config                     = Weather::Config.new( @options )
      @logger                     = Weather::Logger.new( @options )

      unless( options.nil? ) # {{{
        @logger.message( :success, "Starting #{__FILE__} run" )
        @logger.message( :info, "Colorizing output as requested" ) if( @options.colorize )

        ####
        #
        # Main Control Flow
        #
        ##########


        @logger.message( :success, "Finished #{__FILE__} run" )
      end # of unless( options.nil? ) }}}

    end # of initialize }}}

    # @fn       def parse_cmd_arguments( args ) # {{{
    # @brief    The function 'parse_cmd_arguments' takes a number of arbitrary commandline arguments and parses them into a proper data structure via optparse
    #
    # @param    [STDIN]       args    Ruby's STDIN.ARGS from commandline
    #
    # @return   [OpenStruct]          Ruby optparse package options ostruct object
    def parse_cmd_arguments args

      raise ArgumentError, "Argument provided cannot be empty" if( (args == "") or (args.nil?) )

      options                               = OpenStruct.new

      # Define default options
      options.verbose                       = false
      options.clean                         = false
      options.cache                         = false
      options.colorize                      = false
      options.debug                         = false
      options.quiet                         = false
      options.server                        = false
      options.db_path                       = "../data/databases/retina.db"
      options.db_type                       = "sqlite3"

      # TODO: Pass this to webserver class
      options.imagehub_db_path              = "data/databases/imagehub.db"
      options.imagehub_db_type              = "sqlite3"

      options.cache_all_imagehub_data       = false
      options.imagehub_thrift_host          = "localhost"
      options.imagehub_thrift_port          = 9090

      options.robby_thrift_host             = "localhost"
      options.robby_thrift_port             = 5050


      pristine_options        = options.dup

      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{__FILE__.to_s} [options]"

        opts.separator ""
        opts.separator "General options:"

        opts.on("-d", "--db-path PATH", "Use the database which can be found in PATH") do |d|
          options.db_path = d
        end

        opts.on("-t", "--db-type TYPE", "Use the database of class TYPE (e.g. sqlite3)") do |t|
          options.db_type = t
        end

        opts.on("-s", "--server", "Run in webserver mode") do |s|
          options.server = s
        end

        opts.separator ""
        opts.separator "Specific options:"

        opts.on("-a", "--cache-all-imagehub-data", "Cache all imagehub data") do |s|
          options.cache_all_imagehub_data = s
        end

        opts.on("-v", "--verbose", "Run verbosely") do |verbose|
          options.verbose = verbose
        end

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


  # @fn         class Config # {{{
  # @brief      Handles config file
  class Config

    # @fn       def initialize options # {{{
    # @brief    Default constructor for the Config class
    def initialize filename = ENV["HOME"] + "/.weatherrc"
    end # of def initialize # }}}


  end # of class Config # }}}


  # @fn         class Communication # {{{
  # @brief      Handles communication with the weather API
  class Communication

    # @fn       def initialize options # {{{
    # @brief    Default constructor for the Communication class
    def initialize options = nil

    end # of def initialize # }}}


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
