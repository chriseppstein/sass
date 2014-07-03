module Sass
  module Logger
    module LogLevel
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def inherited(subclass)
          subclass.log_levels = subclass.superclass.log_levels.dup
        end

        attr_writer :log_levels

        def log_levels
          @log_levels ||= {}
        end

        def log_level?(level, min_level)
          log_levels[level] >= log_levels[min_level]
        end

        def log_level(name, options = {})
          if options[:prepend]
            level = log_levels.values.min
            level = level.nil? ? 0 : level - 1
          else
            level = log_levels.values.max
            level = level.nil? ? 0 : level + 1
          end
          log_levels.update(name => level)
          define_logger(name)
        end

        def define_logger(name, options = {})
          define_method name do |message|
            send(options.fetch(:to, :log), name, message)
          end
        end
      end
    end
  end
end
