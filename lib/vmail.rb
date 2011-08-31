require 'vmail/version'
require 'vmail/options'
require 'vmail/imap_client'
require 'vmail/query'
require 'vmail/message_formatter'
require 'iconv'

module Vmail
  extend self

  def start
    puts "Starting vmail #{Vmail::VERSION}"
    if  "1.9.0" > RUBY_VERSION
      puts "This version of vmail requires Ruby version 1.9.0 or higher (1.9.2 is recommended)"
      exit(1)
    end

    vmail_home = ENV['VMAIL_HOME'] || File.join(ENV['HOME'], '.vmail')
    vmail_db   = File.join(vmail_home, 'vmail.db')

    # check database version
    print "Checking vmail.db version... "
    db = Sequel.connect "sqlite://#{vmail_db}"
    if (r = db[:version].first) && r[:vmail_version] != Vmail::VERSION
      print "Vmail database version is outdated. Recreating.\n"
      `rm #{vmail_db}`
      `sqlite3 #{vmail_db} < #{CREATE_TABLE_SCRIPT}`
    else
      print "OK\n"
    end

    vim = ENV['VMAIL_VIM'] || 'vim'
    buffer_file = File.expand_path(File.join(vmail_home, "vmailbuffer"))
    puts "Using buffer: #{buffer_file}"

    # Create VMAIL_HOME if it doesn't exist.
    Dir.mkdir(vmail_home, 0700) unless File.exists?(vmail_home)

    ENV['VMAIL_BROWSER'] ||= if RUBY_PLATFORM.downcase.include?('linux')
                               tools = ['gnome-open', 'kfmclient-exec', 'konqueror']
                               tool = tools.detect { |tool|
                                 `which #{tool}`.size > 0
                               }
                               if tool.nil?
                                 puts "Can't find a VMAIL_BROWSER tool on your system. Please report this issue."
                               else
                                 tool
                               end
                             else
                               'open'
                             end

    puts "Setting VMAIL_BROWSER to '#{ENV['VMAIL_BROWSER']}'"
    check_lynx

    opts = Vmail::Options.new(ARGV)
    opts.config
    config = opts.config

    contacts_file      = opts.contacts_file
    should_fork_daemon = opts.fork_daemon

    logfile = (vim == 'mvim' || vim == 'gvim') ? STDERR : "#{vmail_home}/vmail.log"
    config.merge! 'logfile' => logfile

    puts "Using logfile: #{logfile}"

    if should_fork_daemon
        raise 'Fork failed' if (pid = fork) == -1
        exit unless pid.nil?
        Process.setsid
        raise 'Second fork failed' if (pid = fork) == -1
        exit unless pid.nil?
        puts "Daemon pid: #{Process.pid}"
    end

    puts "Starting vmail imap client for #{config['username']}"

    drb_uri = begin
                Vmail::ImapClient.daemon(config, should_fork_daemon)
              rescue
                puts "Failure:", $!
                exit(1)
              end

    $gmail.log "drb_uri = #{drb_uri}"
    server = DRbObject.new_with_uri drb_uri

    mailbox, query = parse_query
    query_string = Vmail::Query.args2string query
    server.select_mailbox mailbox

    #STDERR.puts "Mailbox: #{mailbox}"
    $gmail.log "Mailbox: #{mailbox}"
    #STDERR.puts "Query: #{query.inspect} => #{query_string}"
    $gmail.log "Query: #{query.inspect} => #{query_string}"

    # invoke vim
    vimscript = File.expand_path("../vmail.vim", __FILE__)
    vim_command = "DRB_URI=#{drb_uri} VMAIL_CONTACTS_FILE=#{contacts_file} VMAIL_MAILBOX=#{String.shellescape(mailbox)} VMAIL_QUERY=#{String.shellescape(query_string)} #{vim} -S #{vimscript} #{buffer_file}"

    File.open(buffer_file, "w") do |file|
      file.puts "Vmail starting with values:\n"
      file.puts "$VMAIL_MAILBOX='#{String.shellescape(mailbox)}'"
      file.puts "$VMAIL_QUERY='#{String.shellescape(query_string)}'"
      file.puts "$DRB_URI='#{drb_uri}'"
      file.puts "$VMAIL_CONTACTS_FILE='#{contacts_file}'"
      file.puts "$VMAIL_BROWSER='#{ENV['VMAIL_BROWSER']}'"
      file.puts "INIT_SCRIPT=#{vimscript}"
      file.puts ""
      file.puts "Fetching messages. Please wait..."
    end

    if should_fork_daemon
        $gmail.log "Forked pid=#$$. Leaving connection open."
    else
        system(vim_command)
    end

    if vim == 'mvim' || vim == 'gvim' || should_fork_daemon
      DRb.thread.join
    end

    File.delete(buffer_file)

    #STDERR.puts "Closing imap connection"
    begin
      Timeout::timeout(10) do
        $gmail.close
      end
    rescue Timeout::Error
      puts "Close connection attempt timed out"
    end
    puts "Bye"
    exit(0)
  end


  private

  def check_lynx
    # TODO check for elinks, or firefox (how do we parse VMAIL_HTML_PART_REDAER to determine?)
    if `which lynx` == ''
      STDERR.puts "You need to install lynx on your system in order to see html-only messages"
      sleep 3
    end
  end

  def parse_query
    if ARGV[0] =~ /^\d+/ 
      ARGV.shift
    end
    mailbox = ARGV.shift || 'INBOX' 
    query = Vmail::Query.parse(ARGV)
    [mailbox, query]
  end
end

if __FILE__ == $0
  Vmail.start
end
