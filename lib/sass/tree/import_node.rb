module Sass
  module Tree
    # A static node that wraps the {Sass::Tree} for an `@import`ed file.
    # It doesn't have a functional purpose other than to add the `@import`ed file
    # to the backtrace if an error occurs.
    class ImportNode < RootNode
      # The name of the imported file as it appears in the Sass document.
      #
      # @return [String]
      attr_reader :imported_filename

      # @param imported_filename [String] The name of the imported file
      def initialize(imported_filename)
        @imported_filename = imported_filename
        super(nil)
      end

      def invisible?; to_s.empty?; end

      # Returns the imported file.
      #
      # @return [Sass::Engine]
      # @raise [Sass::SyntaxError] If no file could be found to import.
      def imported_file
        @imported_file ||= import!
      end

      # Returns whether or not this import should emit a CSS @import declaration
      #
      # @return [Boolean] Whether or not this is a simple CSS @import declaration.
      def css_import?
        if @imported_filename =~ /\.css$/
          @imported_filename
        elsif imported_file.is_a?(String) && imported_file =~ /\.css$/
          imported_file
        end
      end

      def import_key
        engine, importer = import
        importer.key(@imported_filename, options) if importer
      end

      private

      def import!
        engine, importer = import
        unless engine
          paths = @options[:load_paths]
          message = "File to import not found or unreadable: #{@imported_filename}.\n"
          if paths.size == 1
            message << "Load path: #{paths.first}"
          else
            message << "Load paths:\n  " << paths.join("\n  ")
          end
          raise SyntaxError.new(message)
        end

        engine
      rescue SyntaxError => e
        raise SyntaxError.new(e.message, :line => self.line, :filename => @filename)
      end

      def import
        unless defined?(@imported_engine)
          @imported_engine, @importer_used = import_relative || import_absolute
        end

        [@imported_engine, @importer_used]
      end

      def import_relative
        if @options[:importer]
          f = @options[:importer].find_relative(
            @imported_filename, @options[:filename], @options.dup)
          return [f, @options[:importer]] if f
        end
        nil
      end

      def import_absolute
        @options[:load_paths].each do |p|
          if f = p.find(@imported_filename, @options.dup)
            return [f, p]
          end
        end

        nil
      end

    end
  end
end
