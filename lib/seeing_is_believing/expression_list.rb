require 'open3'
require 'seeing_is_believing/syntax_analyzer'

# A lot of colouring going on in this file, maybe should extract a debugging object to contain it

class SeeingIsBelieving
  class ExpressionList
    PendingExpression = Struct.new :expression, :children do
      # coloured debug because there's so much syntax that I get lost trying to parse the output
      def inspect(debug=false)
        colour1 = colour2 = lambda { |s| s }
        colour1 = lambda { |s| "\e[30;46m#{s}\e[0m" } if debug
        colour2 = lambda { |s| "\e[37;46m#{s}\e[0m" } if debug
        "#{colour1['PE(']}#{colour2[expression.inspect]}#{colour1[',' ]}#{colour2[children.inspect]}#{colour1[')']}"
      end
    end

    def initialize(options)
      self.debug_stream   = options.fetch :debug_stream, $stdout
      self.should_debug   = options.fetch :debug, false
      self.get_next_line  = options.fetch :get_next_line
      self.peek_next_line = options.fetch :peek_next_line
      self.on_complete    = options.fetch :on_complete
    end

    def call
      offset, expressions, expression = 0, [], nil
      begin
        pending_expression = generate
        debug { "GENERATED: #{pending_expression.expression.inspect}, ADDING IT TO #{inspected_expressions expressions}" }
        expressions << pending_expression
        expression = reduce expressions, offset unless next_line_modifies_current?
        offset += 1
      end until expressions.empty?
      return expression, offset
    end

    private

    attr_accessor :debug_stream, :should_debug, :get_next_line, :peek_next_line, :on_complete, :expressions

    def generate
      expression = get_next_line.call
      raise SyntaxError unless expression
      PendingExpression.new(expression, [])
    end

    def next_line_modifies_current?
      # method invocations can be put on the next line, and begin with a dot.
      # I think that's the only case we need to worry about.
      # e.g: `3\n.times { |i| p i }`
      peek_next_line.call && SyntaxAnalyzer.next_line_modifies_current?(peek_next_line.call)
    end

    def inspected_expressions(expressions)
      "[#{expressions.map { |pe| pe.inspect debug? }.join(', ')}]"
    end

    def debug?
      @should_debug
    end

    def debug
      @debug_stream.puts yield if debug?
    end

    def reduce(expressions, offset)
      expressions.size.times do |i|
        expression = expressions[i..-1].map { |e| [e.expression, *e.children] }
                                       .flatten
                                       .join("\n")        # must use newline otherwise can get expressions like `a\\+b` that should be `a\\\n+b`, former is invalid
        return if children_will_never_be_valid? expression
        next unless valid_ruby? expression
        result = on_complete.call(expressions[i].expression,
                                  expressions[i].children,
                                  expressions[i+1..-1].map { |pe| [pe.expression, pe.children] }.flatten, # hmmm, not sure this is really correct, but it allows it to work for my use cases
                                  offset)
        expressions.replace expressions[0, i]
        expressions[i-1].children << result unless expressions.empty?
        debug { "REDUCED: #{result.inspect}, LIST: #{inspected_expressions expressions}" }
        return result
      end
    end

    def valid_ruby?(expression)
      valid = SyntaxAnalyzer.valid_ruby? expression
      debug { "#{valid ? "\e[32mIS VALID:" : "\e[31mIS NOT VALID:"}: #{expression.inspect}\e[0m" }
      valid
    end

    def children_will_never_be_valid?(expression)
      analyzer = SyntaxAnalyzer.new(expression)
      analyzer.parse
      analyzer.unclosed_string? || analyzer.unclosed_regexp? || SyntaxAnalyzer.unclosed_comment?(expression)
    end
  end
end
