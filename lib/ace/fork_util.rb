# frozen_string_literal: true

# English module required for $CHILD_STATUS rather than $?
require 'English'
require 'json'
require 'ace/error'

module ACE
  class ForkUtil
    # Forks and calls a function
    # It is expected that the function returns a JSON response
    # Throws an exception if JSON.generate fails to generate
    def self.isolate
      reader, writer = IO.pipe
      pid = fork {
        # :nocov:
        success = true
        begin
          response = yield
          writer.puts JSON.generate(response)
        rescue ACE::Error => e
          writer.puts({
            msg: e.message,
            kind: e.kind,
            details: {
              class: e.class,
              backtrace: e.backtrace
            }
          }.to_json)
          success = false
        rescue Exception => e # rubocop:disable Lint/RescueException
          writer.puts({
            msg: e.message,
            kind: e.class,
            details: {
              class: e.class,
              backtrace: e.backtrace
            }
          }.to_json)
          success = false
        ensure
          writer.flush
          Process.exit! success
        end
        # :nocov:
      }
      unless pid
        warn "Could not fork"
        exit 1
      end
      writer.close
      output = reader.readlines('')[0]
      Process.wait(pid)
      if $CHILD_STATUS != 0
        error = JSON.parse(output)
        raise ACE::Error.new(error['msg'], error['kind'], error['details'])
      elsif output.nil?
        raise ACE::Error.new('spawned process returned no result', 'puppetlabs/ace/fork_util', 'no details')
      else
        JSON.parse(output)
      end
    end
  end
end
