require "pty"

class TerminalChannel < ApplicationCable::Channel
  def subscribed
    @pty_master = nil
    @pty_pid = nil
    @reader_thread = nil

    stream_from "terminal_#{current_user.id}"

    spawn_pty
  end

  def unsubscribed
    cleanup_pty
  end

  def receive(data)
    return unless @pty_master

    if data["type"] == "input"
      begin
        @pty_master.write(data["data"])
      rescue Errno::EIO, IOError
        cleanup_pty
      end
    elsif data["type"] == "resize"
      resize_pty(data["cols"].to_i, data["rows"].to_i)
    end
  end

  private

  def spawn_pty
    cleanup_pty if @pty_pid

    shell = ENV["SHELL"] || "/bin/bash"

    # Use PTY.open for read/write access on the master side
    @pty_master, slave = PTY.open

    # Set initial terminal size before spawning
    resize_pty(80, 24)

    # Spawn the shell with the slave as stdin/stdout/stderr
    @pty_pid = Process.spawn(
      { "TERM" => "xterm-256color" },
      shell,
      in: slave, out: slave, err: slave,
      close_others: true
    )

    # Parent doesn't need the slave
    slave.close

    # Reader thread to send PTY output to the client
    @reader_thread = Thread.new do
      begin
        loop do
          break unless @pty_master
          ready = IO.select([@pty_master], nil, nil, 0.1)
          next unless ready

          data = @pty_master.read_nonblock(16384)
          ActionCable.server.broadcast(
            "terminal_#{current_user.id}",
            { type: "output", data: data }
          )
        rescue IO::WaitReadable
          retry
        rescue EOFError, Errno::EIO, IOError
          break
        end
      ensure
        ActionCable.server.broadcast(
          "terminal_#{current_user.id}",
          { type: "exit" }
        )
      end
    end
  end

  def resize_pty(cols, rows)
    return unless @pty_master
    return if cols <= 0 || rows <= 0

    begin
      # TIOCSWINSZ = 0x5414 on Linux
      winsize = [rows, cols, 0, 0].pack("SSSS")
      @pty_master.ioctl(0x5414, winsize)
    rescue Errno::EIO, IOError, Errno::EBADF
      # PTY already closed
    end
  end

  def cleanup_pty
    if @reader_thread
      @reader_thread.kill rescue nil
      @reader_thread = nil
    end

    if @pty_master
      @pty_master.close rescue nil
      @pty_master = nil
    end

    if @pty_pid
      begin
        Process.kill("TERM", @pty_pid)
        Process.wait(@pty_pid)
      rescue Errno::ESRCH, Errno::ECHILD
        # Process already gone
      end
      @pty_pid = nil
    end
  end
end
