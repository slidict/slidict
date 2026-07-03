# frozen_string_literal: true

module Slidict
  module Cli
    # Concern for CLI classes with several constructor dependencies. Declaring
    # `options name: -> { default }, ...` once generates both the attr_reader
    # and the `initialize` assignment, instead of repeating each dependency in
    # the method signature and again as `@name = name` in the body.
    #
    # Defaults are instance_exec'd lazily (only when the keyword is omitted),
    # matching plain keyword-argument defaults, and may reference other
    # options or instance methods (e.g. `-> { method(:default_linter) }`).
    # Classes that need to post-process a value (e.g. expanding a path) can
    # still override `initialize`, call `super`, and adjust the ivar.
    #
    # Also provides a `flag`/`parse_flags!`/`flags_help` DSL: declaring a
    # `-x`/`--xxx` switch once (with its arg placeholder and description)
    # drives both argv parsing and the `--help` listing, so the two can't
    # drift apart. `usage` then only needs to hold the surrounding usage text
    # (Usage:/Commands: lines), interpolating `flags_help` for the option list.
    module Options
      MISSING = Object.new.freeze

      # Process exit codes (see bin/slidict, which does `exit App.new.run(ARGV)`),
      # named so command methods don't scatter bare 0/1 literals as return values.
      SUCCESS = 0
      FAILURE = 1

      def self.included(base)
        base.extend(ClassMethods)
      end

      # One `-x`/`--xxx` declaration: how to parse it (arg placeholder,
      # coercion) and how to describe it in `--help` output.
      Flag = Struct.new(:switches, :key, :arg, :coerce, :desc, keyword_init: true) do
        def boolean?
          arg.nil?
        end

        def short
          switches.find { |s| !s.start_with?("--") }
        end

        def long
          switches.find { |s| s.start_with?("--") }
        end

        # Left column of the help listing, e.g. "-o, --output PATH" or, for a
        # long-only flag, "    --topic TEXT" -- the leading 4 spaces keep the
        # "--name" text column-aligned either way.
        def name_column
          column = "#{short ? "#{short}, " : "    "}#{long}"
          arg ? "#{column} #{arg}" : column
        end
      end

      # Class-level DSL (`options name: -> { default }, ...`) mixed into any
      # class that includes Options.
      module ClassMethods
        # Defines the assignment in an anonymous module (rather than directly
        # on the including class) so a class that needs to post-process a
        # value can still define its own `initialize`, call `super`, and have
        # it reach this one instead of silently overwriting it.
        def options(**defaults)
          attr_reader(*defaults.keys)

          include(Module.new do
            define_method(:initialize) do |**overrides|
              defaults.each do |name, default|
                instance_variable_set(:"@#{name}", resolve_option(name, default, overrides))
              end
            end
          end)
        end

        # Declares a flag. `group` lets a class with several argv shapes
        # (e.g. Slides' `list` vs. `create`/`edit`) keep separate flag sets;
        # `parse_flags!`/`flags_help` default to :default. `desc` may be a
        # Proc (instance_exec'd lazily, like an `options` default) for text
        # that depends on another file having loaded by call time rather
        # than by require time (e.g. `Output::Format.names`).
        def flag(*switches, desc:, arg: nil, coerce: nil, group: :default)
          key = switches.last.sub(/\A-+/, "").tr("-", "_").to_sym
          flag_groups[group] << Flag.new(switches: switches, key: key, arg: arg, coerce: coerce, desc: desc)
        end

        def flag_groups
          @flag_groups ||= Hash.new { |h, k| h[k] = [] }
        end

        def flags(group = :default)
          flag_groups[group]
        end

        # Declares the `-h`/`--help` usage text, generating a private
        # `print_help` that writes it to `@output` and returns SUCCESS,
        # instead of every command spelling that out. Takes a block for the
        # same lazy-evaluation reason as `flag`'s `desc:`.
        def usage(&text)
          private(define_method(:print_help) do
            @output.puts instance_exec(&text)
            SUCCESS
          end)
        end
      end

      private

      def resolve_option(name, default, overrides)
        return overrides[name] if overrides.key?(name)
        raise ArgumentError, "missing keyword: :#{name}" if default.equal?(MISSING)

        instance_exec(&default)
      end

      # Consumes `args` against `self.class.flags(group)`: booleans are set to
      # true, valued flags read their value via the including class's own
      # `fetch_value!` (whose rules on e.g. a leading "-" differ between
      # classes), then any `coerce` is applied.
      def parse_flags!(args, options, group = :default)
        until args.empty?
          arg = args.shift
          flag = self.class.flags(group).find { |f| f.switches.include?(arg) }
          raise ArgumentError, "unknown option #{arg}" unless flag

          value = flag.boolean? || fetch_value!(args, arg)
          value = instance_exec(value, &flag.coerce) if flag.coerce
          options[flag.key] = value
        end
      end

      # Renders `self.class.flags(group)` as an aligned --help listing.
      def flags_help(group = :default)
        defs = self.class.flags(group)
        width = defs.map { |f| f.name_column.length }.max
        defs.map { |f| flag_doc_lines(f, width) }.join("\n")
      end

      def flag_doc_lines(flag, width)
        desc = flag.desc.respond_to?(:call) ? instance_exec(&flag.desc) : flag.desc
        first, *rest = desc.lines(chomp: true)
        lines = ["#{flag.name_column.ljust(width)}  #{first}"]
        rest.each { |line| lines << "#{" " * (width + 2)}#{line}" }
        lines.join("\n")
      end
    end
  end
end
