# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
class GameroomChannel < ApplicationCable::Channel
	def subscribed
		game = Game.find_by(webid: params[:room])
		stream_for game
	end

	def unsubscribed
		# Any cleanup needed when channel is unsubscribed
	end

	def receive data
		@game = Game.find_by(webid: data["webid"])
		history = data["data"]
		# validate history
		@game.update_attributes(history: history)
		if @game.save
			GameroomChannel.broadcast_to(@game, history)
		end
	end
end
