module GamesHelper

	def all_pending_games
		Game.where(in_progress: false, completed: false, private: false)
	end

	# @return board array if move validates, else return nil
	# @return new ko position
	# move should contain {index, color} or {pass}
	def getNewBoard game, move
		if (move['pass'])
			return {board: nil, ko: nil, end_of_game: true} if game.history.last == game.history[-2] # last move was also a pass
			return {board: game.history.last, ko: nil} # normal pass
		end

		board  = Array.new(game.history.last)
		square = move['index']
		ko     = game.ko

		# Can't move where something already is
		return nil if board[square] != ''

		# make the move...
		board[square] = move['color']

		# Can't place a stone that causes itself to be captured unless it captures first
		# Can't place a stone in a ko position that only captures one stone
		# One may not capture just one stone, if that stone was played on the previous move, and that move also captured just one stone.
		# First check if you just captured anything
		captured = getCapturedStones(board, square)
		if captured.any?
			if captured.size == 1 # Captured only one stone, so check/set ko
				if captured[0] == ko # illegal move, trying to capture the ko stone
					return nil
				else # this move is new ko
					ko = square
				end
			else # captured more than one, so reset ko
				ko = nil
			end

			return {board: clearStones(board, captured), ko: ko}
		end


		# Didn't cap anything, ensure no suicide
		return {board: board, ko: nil} if getDeadGroup(Array.new(board), square, board[square]).empty?

		# suicide, illegal move
		return {board: nil, ko: nil}
	end

	def end_game game, data, sender=nil
		type = (data.keys & ['resign', 'draw', 'abort', 'time_up']).first
		case type
			when 'move' #Game ended naturally
				result = calc_winner @game
				if result[:draw]
					game.white_player.involvements.find_by(game_id: game.id).update_attributes(draw: true, winner: false, score: result[:score][:white])
					game.black_player.involvements.find_by(game_id: game.id).update_attributes(draw: true, winner: false, score: result[:score][:black])
				else
					result[:winner].involvements.find_by(game_id: game.id).update_attributes(winner: true, score: result[:score].values.max)
					result[:loser].involvements.find_by(game_id: game.id).update_attributes(winner: false, score: result[:score].values.min)
				end
			when 'resign'
				loser_color = sender.involvements.find_by(game_id: game.id).color
				result      = {
					message: result_message(:resign, !loser_color, loser_color),
					loser:   sender,
					winner:  game.players.where.not(id: sender.id).first
				}
				result[:winner].involvements.find_by(game_id: game.id).update_attributes(winner: true)
				result[:loser].involvements.find_by(game_id: game.id).update_attributes(winner: false)
			when 'draw' #someone accepted draw
				result = {
					message: result_message(:draw),
					draw:    true
				}
			when 'time_up' #someone ran out of time
				loser  = sender
				result = {
					message: result_message(:time, !loser.color, loser.color),
					loser:   Player.find(sender.player_id),
					winner:  game.players.where.not(id: sender.id).first
				}
				result[:winner].involvements.find_by(game_id: game.id).update_attributes(winner: true)
				result[:loser].involvements.find_by(game_id: game.id).update_attributes(winner: false)
			else
				return
		end

		game.update_attributes(in_progress: false, completed: true, result: result[:message])
		return result.slice(:message, :score)

	end

end


private

def calc_winner game
	score = territory(game.history.last)
	case score[:white] <=> score[:black]
		when 1
			{
				message: result_message(:score, 'White', 'Black', score),
				winner:  game.white_player,
				loser:   game.black_player,
				score:   score,
			}
		when 0
			{
				message: result_message(:draw, nil, nil, score),
				draw:    true,
				winner:  nil,
				loser:   nil,
				score:   score,
			}
		when -1
			{
				message: result_message(:score, 'Black', 'White', score),
				winner:  game.black_player,
				loser:   game.white_player,
				score:   score,
			}
	end
end

def bool_to_string bool
	bool ? 'Black' : 'White'
end

def result_message type, winner=nil, loser=nil, score=nil
	winner = bool_to_string winner unless winner.is_a? String
	loser  = bool_to_string loser unless loser.is_a? String
	case type
		when :score
			"#{winner} is victorious. Territory count: #{score[winner.downcase.to_sym]} - #{score[loser.downcase.to_sym]}"
		when :resign
			"#{loser} resigned. #{winner} is victorious."
		when :time
			"#{loser}'s time expired. #{winner} is victorious."
		when :draw
			"Draw. Territory count: #{score[winner.downcase.to_sym]} - #{score[loser.downcase.to_sym]}"
		when :agreement
			"#{loser} agreed to draw."
		when :leave
			"#{loser} left the game. #{winner} is victorious."
		when :abort
			'Game aborted.'
		else
			'Unknown result.'
	end
end

# @return array of dead indices
# board: an array of color strings
# square: index of newest move
def getCapturedStones(board, square)
	captured    = []
	targetColor = !board[square]
	deathBoard  = Array.new(board)
	getDirections(board, square).each_value {|d| captured.concat getDeadGroup(deathBoard, d, targetColor)}
	return captured
end


# @param board, the board
# @param square, index of square in group being checked
# @param target, color being checked
# @return array of dead indices or []
# Note this modifies board
def getDeadGroup board, square, target
	return [] if board[square] != target
	board = Array.new(board)
	queue = [square]
	dead  = []
	until queue.empty? do
		n = queue.shift
		dead.push n
		board[n] = 'R'
		dirs     = getDirections(board, n)
		# If there is an empty square adjacent, group is not dead
		return [] if board.values_at(*dirs.values).include? ''
		dirs.each_value {|dir| queue.push(dir) if board[dir]==target}
	end
	return dead
end

def clearStones board, deaths
	return board if deaths.empty?
	newBoard = Array.new(board)
	deaths.each {|i| newBoard[i] = ''}
	return newBoard
end

# @return {white: int, black:int}
# This is temporary. When making real implementation see GNUGo docs, chapters 15 and 17
def territory(board)
	target      = ''
	replacement = '!'
	board       = Array.new(board)
	square      = board.index(target)
	until square.nil?
		queue = [square]
		hits  = []
		until queue.empty? do
			n        = queue.shift
			board[n] = replacement
			dirs     = getDirections(board, n)
			# If it hits two, group is neutral
			hits |= board.values_at(*dirs.values)
			dirs.each_value {|dir| queue |= [dir] if board[dir]==target}
		end
		square = board.index(target)
		board.map! do |char|
			next char unless char == replacement
			next 'N' if hits.keep_if {|s| s.in? [true, false]}.size > 1
			hits.first
		end
	end
	return {white: board.count(false), black: board.count(true)}
end

# @return hash of form {direction: index}
# if OOB return same index
def getDirections board, index, filter=nil
	dimensions = Math.sqrt(board.size) #19
	directions = {
		left:  index % dimensions != 0 ? index - 1 : index,
		right: (index + 1) % dimensions != 0 ? index + 1 : index,
		up:    index >= dimensions ? index-dimensions : index,
		down:  index < dimensions * (dimensions - 1) ? index + dimensions : index
	}
	return directions unless filter
	return directions[filter]
end


#  O O X -
#  O x O X
#  X X X -
#  - - - -

