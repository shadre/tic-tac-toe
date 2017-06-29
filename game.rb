module VisualSettings
  H_LINE             = " *───────*───────*───────* "
  V_LINE             = " | "
  SQ_WIDTH           = 5
  V_LINES_WITH_SPACE = ((V_LINE + (" " * SQ_WIDTH)) * 3) + V_LINE

  PROMPT      = ">> "
  TBL_MARGIN  = " " * (PROMPT.size - 1)
  TXT_MARGIN  = TBL_MARGIN + " "
end

module UX
  include VisualSettings

  def clear_screen
    system("cls") || system("clear")
  end

  def join_or(array, separator = ", ", or_word = "or")
    return array.first if array.size < 2

    array[-1] = "#{or_word} #{array[-1]}"
    array.join(separator)
  end

  def prompt(*messages)
    messages.each { |msg| puts PROMPT + msg }
  end
end

module UI
  require 'io/console'
  include VisualSettings

  TERMINATION_CHARS = { "\u0003" => "^C",
                        "\u0004" => "^D",
                        "\u001A" => "^Z" }

  def get_char(args)
    get_input(**args) { yield_char }
  end

  def get_string(args)
    get_input(**args) { gets.strip }
  end

  def wait_for_any_key(message = PROMPT + "Press ANY KEY to continue")
    puts message
    yield_char
  end

  private

  def get_input(message:, invalid_msg: "Invalid input!", expected: nil)
    puts PROMPT + message
    loop do
      input = yield

      break input unless (expected && !expected.include?(input)) || input.empty?

      puts PROMPT + invalid_msg
    end
  end

  def yield_char
    char_input = STDIN.getch.downcase

    termination_input = TERMINATION_CHARS[char_input]
    abort("Program aborted (#{termination_input})") if termination_input

    char_input
  end
end

module GameHandler
  extend UI, UX

  class << self
    def display_goodbye_message
      prompt "Thanks for playing. Bye!"
    end

    def display_welcome_message
      clear_screen
      prompt "Welcome to Tic-Tac-Toe!"
    end

    def rematch?
      answer = get_char(message:     "Would you like to play again? (y/n)",
                        expected:    %w[y n],
                        invalid_msg: "Please choose 'y' or 'n'")
      answer == "y"
    end

    def start_ttt
      display_welcome_message
      players = [Human.new("X"), Computer.new("O")]
      loop do
        Game.new(players, Board.new).play
        break display_goodbye_message unless rematch?
        clear_screen
      end
    end
  end
end

class Game
  include UI, UX

  SEQUENCE_ADJUST = { random:  :shuffle,
                      player1: :itself,
                      player2: :reverse }
  STARTING_PLAYER = :random

  def initialize(players, board)
    @players  = players
    @board    = board
    @sequence = new_sequence
  end

  def play
    intro
    next_move until board.end_state?
    display_board
    display_result
  end

  private

  attr_reader :board, :players, :sequence

  def adjust_sequence
    sequence.reverse!
  end

  def current_player
    sequence.first
  end

  def display_board
    puts board
  end

  def display_result
    return prompt "#{winner} wins!" if winner

    prompt "It's a tie!"
  end

  def display_marks_info
    prompt "Player marks are:"
    players.each { |player| puts TXT_MARGIN + "#{player.mark} - #{player}" }
    puts
  end

  def intro
    display_marks_info
    wait_for_any_key
    clear_screen
  end

  def new_sequence
    players.send(SEQUENCE_ADJUST[STARTING_PLAYER])
  end

  def next_move
    display_board
    current_player.make_move(board)
    adjust_sequence
    clear_screen
  end

  def winner
    players.find { |player| player.mark == board.winning_mark }
  end
end

class Board
  include UX

  attr_reader :squares

  RANGE = (1..9)
  LINES = [1, 2, 3], [4, 5, 6], [7, 8, 9], # horizontals
          [1, 4, 7], [2, 5, 8], [3, 6, 9], # verticals
          [1, 5, 9], [7, 5, 3]             # diagonals

  def initialize
    @squares = empty_board
  end

  def [](num)
    squares[num]
  end

  def []=(num, mark)
    squares[num] = mark
  end

  def end_state?
    full? || winning_mark
  end

  def full?
    squares.values.all?
  end

  def to_s
    board_strings.join("\n")
  end

  def unmarked
    squares.reject { |_, mark| mark }
           .keys
  end

  def valid_move?(num)
    RANGE.include?(num) && !squares[num]
  end

  def winning_mark
    @winning_mark ||= find_winner
  end

  private

  attr_writer :squares

  def all_same?(values)
    return nil unless values.all?

    values.uniq.size == 1
  end

  def board_strings
    hr_border_line = TBL_MARGIN + H_LINE

    (squares.each_slice(3).map { |row| [hr_border_line, row_strings(row)] } <<
      hr_border_line).flatten
  end

  def empty_board
    RANGE.map { |num| [num, nil] }
         .to_h
  end

  def find_winner
    line_values.each do |values|
      result = values.first if all_same?(values)

      return result if result
    end
    nil
  end

  def line_values
    LINES.map { |line| squares.values_at(*line) }
  end

  def row_strings(row)
    inner_empty_line = TBL_MARGIN + V_LINES_WITH_SPACE
    [inner_empty_line, row_with_symbols(row), inner_empty_line]
  end

  def row_with_symbols(row)
    TBL_MARGIN + V_LINE + row.map { |square| symbol(square) + V_LINE }.join
  end

  def symbol(square)
    number, mark = square

    (mark ? mark : "<#{number}>")
      .center(SQ_WIDTH)
  end
end

class Player
  attr_reader :mark, :name

  def initialize(mark)
    @name = new_name
    @mark = mark
  end

  def make_move(board)
    loop do
      choice = choose_move(board)
      break board[choice] = mark if board.valid_move?(choice)
      handle_invalid_move(board)
    end
  end

  private

  def choose_move(_board)
    raise NotImplementedError,
          "method not implemented in #{self.class}"
  end

  def handle_invalid_move(_board); end

  def new_name
    "Player"
  end

  def to_s
    name
  end
end

class Human < Player
  include UI, UX

  def choose_move(_board)
    get_char(message: "Please choose a move:").to_i
  end

  def handle_invalid_move(board)
    valid_moves = board.unmarked
    prompt(
      if valid_moves.size == 1
        "You can only choose #{valid_moves.first}!"
      else
        "Invalid move! Please choose #{join_or(valid_moves)}."
      end
    )
  end
end

class Computer < Player
  def choose_move(board)
    board.unmarked.sample
  end

  private

  def new_name
    "Computer"
  end
end

GameHandler.start_ttt
