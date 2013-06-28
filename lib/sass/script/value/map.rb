module Sass::Script
  class Map < Literal
    attr_reader :value

    def initialize(hash)
      super(hash)
    end

    def children
      value.keys + value.values
    end

    def deep_copy
      node = dup
      node.instance_variable_set('@value',
        Sass::Util.map_hash(value) {|k, v| [k.deep_copy, v.deep_copy]})
      node
    end

    def eq(other)
      Sass::Script::Bool.new(other.is_a?(Map) && self.value == other.value)
    end

    def to_s(opts = {})
      raise Sass::SyntaxError.new("#{inspect} isn't a valid CSS value.")
    end

    def to_sass(opts = {})
      return "()" if value.empty?

      to_sass = lambda do |value|
        if value.is_a?(Map) || (value.is_a?(List) && value.separator == :comma)
          "(#{value.to_sass(opts)})"
        else
          value.to_sass(opts)
        end
      end

      value.map {|(k, v)| "#{to_sass[k]}: #{to_sass[v]}"}.join(', ')
    end

    def inspect
      "(#{to_sass})"
    end

    protected

    # @see Node#_perform
    def _perform(environment)
      # TODO: disallow duplicate keys here
      map = Sass::Script::Map.new(Sass::Util.map_hash(value) do |k, v|
        [k.perform(environment), v.perform(environment)]
      end)
      map.options = self.options
      map
    end
  end
end
