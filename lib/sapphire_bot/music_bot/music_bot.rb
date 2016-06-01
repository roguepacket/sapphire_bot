module SapphireBot
  module MusicBot
    MAX_SONG_LENGTH = 600

    MAX_SONGS_IN_QUEUE = 15

    @servers = {}

    Struct.new('Song', :title, :duration, :path, :url, :ready, :repeat)

    def self.servers
      @servers
    end

    def self.add_server(id)
      @servers[id] = ServerQueue.new(id)
    end

    def self.delete_server(id)
      @servers[id].delete_dir
      @servers.delete(id)
    end

    def self.delete_files
      @servers.each do |_key, value|
        value.delete_dir
      end
    end

    class ServerQueue
      attr_reader :id, :queue, :playing

      def initialize(id)
        @id = id
        @queue = []
        @playing = false
        @server_dir = "#{Dir.pwd}/data/music_bot/#{id}"
        @download_options = {
          extract_audio: true,
          audio_format: 'mp3',
          format: :worst,
          output: "#{@server_dir}/%(title)s.mp3"
        }

        delete_dir if Dir.exist?(@server_dir)
      end

      def download_song(video_id, event)
        song = YoutubeDL::Video.new(video_id, @download_options)

        if song.duration >= MAX_SONG_LENGTH
          event.respond("Song \"#{song.title}\" is longer than allowed (#{MAX_SONG_LENGTH}s).")
          return
        else
          if song.duration >= MAX_SONG_LENGTH / 2
            event.respond("Downloading \"#{song.title}\", this might take a while.")
          else
            event.respond("Downloading \"#{song.title}\".")
          end
          struct = Struct::Song.new(song.title,
                                    duration_format(song.duration),
                                    song.filename, "https://youtu.be/#{song.url}",
                                    false,
                                    false)
          @queue << struct
          song.download
          @queue.find { |x| x == struct }.ready = true
        end
      end

      def start_loop(event)
        unless @playing || @queue.first.nil?
          Thread.new do
            retries = 0
            loop do
              song = @queue.first
              if song.ready
                play_song(event, song)
              else
                break if retries >= 5
                event.respond("\"#{song.title}\" is not ready yet, will start playing once it is.")
                sleep(10)
                retries += 1
              end
              break if @queue.empty?
            end
            @playing = false
          end
        end
      end

      def table
        Terminal::Table.new(headings: %w(# Name Duration Link)) do |t|
          @queue.each_with_index do |song, index|
            title = if song.title.length >= 28
                      song.title[0..25] + '...'
                    else
                      song.title
                    end
            duration = song.duration
            url = "<#{song.url}>"
            t.add_row([index + 1, title, duration, url])
          end
        end
      end

      def delete_dir
        FileUtils.rm_rf(@server_dir)
        @queue = []
      end

      def delete_first_song
        delete_song(@queue.first)
      end

      def delete_song(song)
        @queue.delete(song)
        File.delete(song.path) if File.exist?(song.path)
      end

      def delete_song_at(index)
        file = @queue[index].path
        @queue.delete_at(index)
        File.delete(file) if File.exist?(file)
      end

      private

      def play_song(event, song)
        @playing = true
        event.respond("Playing \"#{song.title}\" (#{song.duration}) #{song.url}")
        loop do
          event.voice.play_file(song.path)
          unless song.repeat
            delete_first_song
            return
          end
          STATS.stats_hash[:songs_played] += 1
        end
      end

      def duration_format(seconds)
        minutes = seconds / 60
        seconds -= minutes * 60
        "#{'0' if minutes < 10}#{minutes}:#{'0' if seconds < 10}#{seconds}"
      end
    end
  end
end
