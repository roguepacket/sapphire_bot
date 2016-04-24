module SapphireBot
  module Commands
    module Invite
      extend Discordrb::Commands::CommandContainer
      command(:invite, description: 'Prints information about inviting this bot to your sever.',
                       bucket: :default) do |event|
        event << 'To invite me to your server, click on the link below and select server.'
        event << 'Only users with `manage server` permission are able to invite me.'
        event << event.bot.shortener.shorten("#{event.bot.invite_url}+&permissions=#{PERMISSIONS_CODE}", event.bot)
      end
    end
  end
end