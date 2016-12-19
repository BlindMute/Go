class GamesController < ApplicationController


	def index
		@games = Game.all #magically goes to the view
	end
	
	def new

	end

	def create
		@game = Game.new(params.require(:game).permit(:name))
		current_user.games << @game
		@game.history = [squares: Array.new(9).fill("")]
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
			@game.players << current_user unless (@game.players.include?(current_user) || current_user.nil?)
			# Change this part when anon users implemented
		end
		@game
	end

	def edit
		@history = params
	end

	def update
		@game = Game.find_by(webid: params[:webid])
		history = params[:_json]
		# validate history
		@game.update_attributes(history: history)
		@game.save
		render json: @game.history
	end
end
