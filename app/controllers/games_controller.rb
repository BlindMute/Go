class GamesController < ApplicationController


	def index
		@games = Game.joins(:players).group('id').having('count(players.id)<2').to_json(include: :players) #magically goes to the view
	end
	
	def new
		create
	end

	def create
		@game         = current_user.games.build
		@game.history = [squares: Array.new(361).fill('')]
		current_user.involvements.last.update(color: true) #1 black, 0 white
		@game.save
		redirect_to @game #redirects to game_path/id which hits routes

		#need to add white and black IDs when chosen
	end

	def show
		@game = Game.find_by(webid: params[:webid]) #these @vars are magically sent to the view
		if @game.players.count >=2
			# Join as spectator
		else
			# Join as player
			unless @game.players.include?(current_user) || current_user.nil?
				@game.players << current_user
				current_user.involvements.last.update(color: false)
				@game.save
			end
			ActionCable.server.broadcast 'games', Game.joins(:players).group('id').having('count(players.id)<2').to_json(include: :players)
			# Change this part when anon users implemented
		end
		@game
	end

	def edit
		# @history = params
	end

	def update
		# @game = Game.find_by(webid: params[:webid])
		# history = params[:_json]
		# # validate history
		# @game.update_attributes(history: history)
		# if @game.save
		# 	ActionCable.server.broadcast 'game_channel',
		# 								 message: 'hi im a message',
		# 								 user: @game.players.first
		# 	head :ok
		# 	render json: @game.history
		# end

	end
end
