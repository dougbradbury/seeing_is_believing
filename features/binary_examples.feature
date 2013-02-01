Feature: Running the binary successfully

  They say seeing is believing. So to believe that this works
  I want to see that it works by making a binary to use the lib.

  It should be approximately like xmpfilter, except that it should
  run against every line.

  Scenario: Some basic functionality
    Given the file "basic_functionality.rb":
    """
    5.times do |i|
      i * 2
    end

    def meth(n)
      n
    end

    # some invocations
    meth "12"
    meth "34"

    =begin
    I don't ever actually write
      comments like this
    =end

    # multilinezzz
    "a
     b
     c"
    """
    When I run "seeing_is_believing basic_functionality.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    5.times do |i|
      i * 2         # => 0, 2, 4, 6, 8
    end             # => 5

    def meth(n)
      n             # => "12", "34"
    end             # => nil

    # some invocations
    meth "12"       # => "12"
    meth "34"       # => "34"

    =begin
    I don't ever actually write
      comments like this
    =end

    # multilinezzz
    "a
     b
     c"             # => "a\n b\n c"
    """

  Scenario: Passing previous output back into input
    Given the file "previous_output.rb":
    """
    1 + 1  # => not 2
    2 + 2  # ~> Exception, something


    # >> some stdout output

    # !> some stderr output
    __END__
    """
    When I run "seeing_is_believing previous_output.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1 + 1  # => 2
    2 + 2  # => 4

    __END__
    """

  Scenario: Printing within the file
    Given the file "printing.rb":
    """
    print "hel"
    puts  "lo!"
    puts  ":)"
    $stderr.puts "goodbye"
    """
    When I run "seeing_is_believing printing.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    print "hel"             # => nil
    puts  "lo!"             # => nil
    puts  ":)"              # => nil
    $stderr.puts "goodbye"  # => nil

    # >> hello!
    # >> :)

    # !> goodbye
    """

  Scenario: Respects macros
    Given the file "some_dir/uses_macros.rb":
    """
    __FILE__
    __LINE__
    $stdout.puts "omg"
    $stderr.puts "hi"
    DATA.read
    __LINE__
    __END__
    1
    2
    """
    When I run "seeing_is_believing some_dir/uses_macros.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    __FILE__            # => "{{CommandLineHelpers.path_to 'some_dir/uses_macros.rb'}}"
    __LINE__            # => 2
    $stdout.puts "omg"  # => nil
    $stderr.puts "hi"   # => nil
    DATA.read           # => "1\n2"
    __LINE__            # => 6

    # >> omg

    # !> hi
    __END__
    1
    2
    """

  @not-implemented
  Scenario: Doesn't record BEGIN/END since that's apparently a syntax error
    Given the file "BEGIN_and_END.rb":
    """
    puts 1
    BEGIN {
      puts "begin code"
      some_var = 2
    }
    puts 3
    END {
      puts "end code"
      puts some_var
    }
    puts 4
    """
    When I run "seeing_is_believing BEGIN_and_END.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    puts 1               # => nil
    BEGIN {
      puts "begin code"  # => nil
      some_var = 2       # => 2
    }
    puts 3               # => nil
    END {
      puts "end code"    # => nil
      puts some_var      # => nil
    }
    puts 4               # => nil

    # >> begin code
    # >> 1
    # >> 3
    # >> 4
    # >> end code
    # >> 2
    """

  Scenario: Passing the file on stdin
    Given I have the stdin content "hi!"
    And the file "reads_from_stdin.rb":
    """
    puts "You said: #{gets}"
    """
    When I run "seeing_is_believing reads_from_stdin.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    puts "You said: #{gets}"  # => nil

    # >> You said: hi!
    """
