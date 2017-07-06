module VisualSettings
  PROMPT     = ">> "
  TBL_MARGIN = " " * (PROMPT.size - 1)
end

module UX
  include VisualSettings

  def clear_screen
    system("cls") || system("clear")
  end

  def concat_on_both_sides(original, left, right = nil)
    right ||= left

    left + original + right
  end

  def join_or(array)
    return array.first if array.size < 2

    array[0..-2].join(", ") + " or #{array.last}"
  end

  def print_in_border(text)
    hr_line   = "".center(text.length + 2, "=")
    hr_border = concat_on_both_sides(hr_line, "+")
    text_line = concat_on_both_sides(text, "| ", " |")

    puts with_margins([hr_border, text_line, hr_border])
  end

  def prompt(*messages)
    messages.each { |msg| puts PROMPT + msg }
  end

  def with_margins(str_array, margin = TBL_MARGIN)
    str_array.map { |str| margin + str }
  end
end

module UI
  require 'io/console'
  include UX, VisualSettings

  TERMINATION_CHARS = { "\u0003" => "^C",
                        "\u0004" => "^D",
                        "\u001A" => "^Z" }

  def get_char(args)
    get_input(**args) { yield_char }
  end

  def get_string(args)
    get_input(**args) { gets.strip }
  end

  def wait_for_any_key
    get_char(message: "Press ANY KEY to continue")
  end

  private

  def fitting?(expected, input)
    !expected || expected.include?(input)
  end

  def get_input(message:, invalid_msg: "Invalid input!", expected: nil)
    prompt message
    loop do
      input = yield

      return input if !input.empty? && fitting?(expected, input)

      prompt invalid_msg
    end
  end

  def quit_if_terminating(char_input)
    termination_input = TERMINATION_CHARS[char_input]
    abort("Program aborted (#{termination_input})") if termination_input
  end

  def yield_char
    char_input = STDIN.getch.downcase

    quit_if_terminating(char_input)

    char_input
  end
end

class Match
  include UI, UX

  POINTS_TO_WIN = 2

  def initialize(players)
    @players    = players
    @scoreboard = new_scoreboard
  end

  def start
    clear_screen
    display_welcome_message
    display_winning_condition
    puts
    play
  end

  private

  attr_reader :players, :scoreboard
  attr_accessor :winner

  def ask_about_rematch_decision
    get_char(message:     "Would you like to play again? (y/n)",
             expected:    %w[y n],
             invalid_msg: "Please choose 'y' or 'n'")
  end

  def check_winner
    self.winner = players.find { |player| player.points == POINTS_TO_WIN }
  end

  def display_goodbye_message
    prompt "Thanks for playing. Bye!"
  end

  def display_score
    print_in_border(scoreboard.to_s)
    puts
  end

  def display_welcome_message
    prompt "Welcome to Tic-Tac-Toe!"
  end

  def display_winner
    prompt "#{winner} wins the match!"
  end

  def display_winning_condition
    prompt "First player to win #{POINTS_TO_WIN} games wins the match!"
  end

  def new_scoreboard
    Scoreboard.new(*players)
  end

  def next_game
    Game.new(players, Board.new).play
    clear_screen
    display_score
  end

  def play
    loop do
      play_games_until_winner
      break display_goodbye_message unless rematch?
      reset_match
      clear_screen
    end
  end

  def play_games_until_winner
    until winner
      next_game
      check_winner
    end
    display_winner
  end

  def rematch?
    ask_about_rematch_decision == "y"
  end

  def reset_match
    reset_score
    reset_winner
  end

  def reset_score
    players.each(&:reset_points)
  end

  def reset_winner
    self.winner = nil
  end

  Scoreboard = Struct.new(:player1, :player2) do
    def to_s
      "#{player1} #{player1.points} : #{player2.points} #{player2}"
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
    handle_outcome
  end

  private

  attr_reader :board, :players, :sequence
  attr_accessor :winner

  def current_player
    sequence.first
  end

  def display_board
    puts board
    puts
  end

  def display_result
    return prompt "#{winner} wins!" if winner

    prompt "It's a tie!"
  end

  def display_marks_info
    prompt "Player marks are:"
    players.each { |player| prompt "#{player.mark} - #{player}" }
    puts
  end

  def find_winner
    self.winner = players.find { |player| player.mark == board.winning_mark }
  end

  def handle_outcome
    find_winner
    update_points
    display_result
    wait_for_any_key
  end

  def intro
    display_marks_info
    wait_for_any_key
    clear_screen
  end

  def move_sequence
    sequence << sequence.shift
  end

  def new_sequence
    players.send(SEQUENCE_ADJUST[STARTING_PLAYER])
  end

  def next_move
    display_board
    current_player.make_move(board)
    move_sequence
    clear_screen
  end

  def update_points
    winner&.add_point
  end
end

module BoardDrawing
  include VisualSettings

  SQUARE_WIDTH  = 7
  V_LINE_SYM    = "|"
  H_LINE_SYM    = "─"
  INTERSECT_SYM = "*"

  def to_s
    boardize(symbols)
  end

  private

  def add_bottom_line(row_array)
    row_array << hr_line
  end

  def adjust_widths(str_array)
    str_array.map { |el| el.center(SQUARE_WIDTH) }
  end

  def blank_row_line
    rowize([" "] * 3)
  end

  def boardize(symbols)
    with_margins(transform(symbols)).join("\n")
  end

  def hr_line
    rowize([H_LINE_SYM * SQUARE_WIDTH] * 3, INTERSECT_SYM)
  end

  def rowize(values, joining = V_LINE_SYM)
    adjust_widths(values).join(joining)
  end

  def symbols
    squares.map { |number, value| value || "<#{number}>" }
  end

  def transform(symbols)
    symbols.each_slice(3).with_index.map do |values, idx|
      row_array = whole_row(values)

      idx == 2 ? row_array : add_bottom_line(row_array)
    end.flatten
  end

  def values_row_line(values)
    rowize(values)
  end

  def whole_row(values)
    [blank_row_line, values_row_line(values), blank_row_line]
  end
end

class Board
  include BoardDrawing, UX

  RANGE = (1..9)
  LINES = [1, 2, 3], [4, 5, 6], [7, 8, 9], # horizontals
          [1, 4, 7], [2, 5, 8], [3, 6, 9], # verticals
          [1, 5, 9], [7, 5, 3]             # diagonals

  attr_reader :squares

  def initialize
    @squares = empty_board
  end

  def [](num)
    squares[num]
  end

  def []=(num, mark)
    squares[num] = mark
  end

  def empty?
    marks.none?
  end

  def end_state?
    full? || winning_mark
  end

  def full?
    marks.all?
  end

  def marks
    squares.values
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
end

class Player
  attr_reader :mark, :name, :points

  def initialize(mark)
    @name   = assign_name
    @mark   = mark
    reset_points
  end

  def add_point
    self.points += 1
  end

  def make_move(board)
    loop do
      choice = choose_move(board)
      break board[choice] = mark if board.valid_move?(choice)
      handle_invalid_move(board)
    end
  end

  def reset_points
    @points = 0
  end

  private

  attr_writer :points

  def assign_name
    "Player"
  end

  def choose_move(_board)
    raise NotImplementedError,
          "method not implemented in #{self.class}"
  end

  def handle_invalid_move(_board); end

  def to_s
    name
  end
end

class Human < Player
  include UI, UX

  private

  def choose_move(_board)
    get_char(message: "Please choose a move:").to_i
  end

  def handle_invalid_move(board)
    prompt "Invalid move! Please choose #{join_or(board.unmarked)}."
  end
end

module Minimax
  private

  attr_accessor :analyzed_board

  class BoardClone < Board
    def initialize(cloned_board)
      @squares = cloned_board.squares.dup
    end
  end

  RIVAL = { ai:    :rival,
            rival: :ai }
  STRAT = { ai:    :max,
            rival: :min }

  WIN_VALUE  = 1
  TIE_VALUE  = 0
  LOSS_VALUE = -1

  CORNER_CHOICES = [1, 3, 7, 9]

  def available_moves_values(game_state, player)
    game_state.unmarked.map { |move| minimax(game_state, move, player) }
  end

  def best_value_for(player, move_values)
    move_values.send(STRAT[player])
  end

  def choose_move(board)
    self.analyzed_board = board
    chosen_move
  end

  def chosen_move
    return random_corner if analyzed_board.empty?

    win_expectant_move || tie_expectant_move
  end

  def copy(board)
    BoardClone.new(board)
  end

  def end_state_value(board)
    winning_mark = board.winning_mark
    return TIE_VALUE unless winning_mark

    (winning_mark == mark ? WIN_VALUE : LOSS_VALUE)
  end

  def find_move_by_value(value)
    analyzed_board.unmarked.find do |move|
      minimax(analyzed_board, move) == value
    end
  end

  def minimax(board, move, player = :ai)
    game_state = copy(board)
    opponent   = rival_of(player)
    curr_mark  = (player == :ai ? mark : rival_mark)

    game_state[move] = curr_mark

    return end_state_value(game_state) if game_state.end_state?

    best_value_for(opponent, available_moves_values(game_state, opponent))
  end

  def random_corner
    CORNER_CHOICES.sample
  end

  def rival_mark
    analyzed_board.marks.find { |symbol| symbol && symbol != mark }
  end

  def rival_of(player)
    RIVAL[player]
  end

  def tie_expectant_move
    find_move_by_value(TIE_VALUE)
  end

  def win_expectant_move
    find_move_by_value(WIN_VALUE)
  end
end

class Computer < Player
  include Minimax

  private

  def assign_name
    "Computer"
  end
end

Match.new([Human.new("X"), Computer.new("O")]).start
