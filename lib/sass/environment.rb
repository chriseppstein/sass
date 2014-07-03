require 'set'

module Sass
  # The abstract base class for lexical environments for SassScript.
  class BaseEnvironment
    class << self
      # Note: when updating this,
      # update sass/yard/inherited_hash.rb as well.
      def inherited_hash_accessor(name)
        inherited_hash_reader(name)
        inherited_hash_writer(name)
      end

      def inherited_hash_reader(name)
        names_ivar = :"@#{name}s"
        underscore_name = :"_#{name}"
        is_global_name = :"is_#{name}_global?"
        define_method(name) do |n|
          send(underscore_name, n.tr('_', '-'))
        end

        define_method(underscore_name) do |n|
          names = instance_variable_get(names_ivar)
          names && names[n] || @parent && @parent.send(underscore_name, n)
        end
        protected underscore_name

        define_method(is_global_name) do |n|
          names = instance_variable_get(names_ivar)
          return !@parent if names && names.has_key?(n)
          @parent && @parent.send(is_global_name, n)
        end
      end

      def inherited_hash_writer(name)
        names_ivar = :"@#{name}s"
        set_name = :"set_#{name}"
        try_set_name = :"try_set_#{name}"
        set_local_name = :"set_local_#{name}"
        set_global_name = :"set_global_#{name}"

        define_method(set_name) do |n, value|
          names = instance_variable_get(names_ivar) || instance_variable_set(names_ivar, {})
          n = n.tr('_', '-')
          names[n] = value unless send(try_set_name, n, value)
        end
        define_method(try_set_name) do |n, value|
          names = instance_variable_get(names_ivar) || instance_variable_set(names_ivar, {})
          if names.include?(n)
            names[n] = value
            true
          elsif @parent
            @parent.send(try_set_name, n, value)
          else
            false
          end
        end
        protected try_set_name

        define_method(set_local_name) do|n, value|
          names = instance_variable_get(names_ivar) || instance_variable_set(names_ivar, {})
          names[n.tr('_', '-')] = value
        end
      end
    end

    # The options passed to the Sass Engine.
    attr_reader :options

    attr_writer :caller
    attr_writer :content
    attr_writer :selector

    # variable
    # Script::Value
    inherited_hash_reader :var

    # mixin
    # Sass::Callable
    inherited_hash_reader :mixin

    # function
    # Sass::Callable
    inherited_hash_reader :function

    # Whether a warning has been emitted for assigning to the given
    # global variable. This is a set of tuples containing the name of
    # the variable, its filename, and its line number.
    #
    # @return [Set<[String, String, int]>]
    attr_reader :global_warning_given

    # Whether a warning has been emitted for misusing a deprecated false value.
    # This is a set of tuples containing the filename and its line number.
    #
    # @return [Set<[String, int]>]
    attr_reader :deprecated_false_warning_given

    # @param options [{Symbol => Object}] The options hash. See
    #   {file:SASS_REFERENCE.md#sass_options the Sass options documentation}.
    # @param parent [Environment] See \{#parent}
    def initialize(parent = nil, options = nil)
      @parent = parent
      @options = options || (parent && parent.options) || {}
      @stack = Sass::Stack.new if @parent.nil?
      @global_warning_given = Set.new
      @deprecated_false_warning_given = Set.new
    end

    # The environment of the caller of this environment's mixin or function.
    # @return {Environment?}
    def caller
      @caller || (@parent && @parent.caller)
    end

    # The content passed to this environment. This is naturally only set
    # for mixin body environments with content passed in.
    #
    # @return {[Array<Sass::Tree::Node>, Environment]?} The content nodes and
    #   the lexical environment of the content block.
    def content
      @content || (@parent && @parent.content)
    end

    # The selector for the current CSS rule, or nil if there is no
    # current CSS rule.
    #
    # @return [Selector::CommaSequence?] The current selector, with any
    #   nesting fully resolved.
    def selector
      @selector || (@caller && @caller.selector) || (@parent && @parent.selector)
    end

    # The top-level Environment object.
    #
    # @return [Environment]
    def global_env
      @global_env ||= @parent.nil? ? self : @parent.global_env
    end

    # The import/mixin stack.
    #
    # @return [Sass::Stack]
    def stack
      @stack || global_env.stack
    end
  end

  # The lexical environment for SassScript.
  # This keeps track of variable, mixin, and function definitions.
  #
  # A new environment is created for each level of Sass nesting.
  # This allows variables to be lexically scoped.
  # The new environment refers to the environment in the upper scope,
  # so it has access to variables defined in enclosing scopes,
  # but new variables are defined locally.
  #
  # Environment also keeps track of the {Engine} options
  # so that they can be made available to {Sass::Script::Functions}.
  class Environment < BaseEnvironment
    # The enclosing environment,
    # or nil if this is the global environment.
    #
    # @return [Environment]
    attr_reader :parent

    # variable
    # Script::Value
    inherited_hash_writer :var

    # mixin
    # Sass::Callable
    inherited_hash_writer :mixin

    # function
    # Sass::Callable
    inherited_hash_writer :function
  end

  # A read-only wrapper for a lexical environment for SassScript.
  class ReadOnlyEnvironment < BaseEnvironment
    # The read-only environment of the caller of this environment's mixin or function.
    #
    # @see BaseEnvironment#caller
    # @return {ReadOnlyEnvironment}
    def caller
      return @caller if @caller
      env = super
      @caller ||= env.is_a?(ReadOnlyEnvironment) ? env : ReadOnlyEnvironment.new(env, env.options)
    end

    # The read-only content passed to this environment.
    #
    # @see BaseEnvironment#content
    # @return {ReadOnlyEnvironment}
    def content
      return @content if @content
      env = super
      @content ||= env.is_a?(ReadOnlyEnvironment) ? env : ReadOnlyEnvironment.new(env, env.options)
    end
  end
end
