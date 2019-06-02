class ConversationCreator
  class << self
    def create(author:, recipient_username:, subject:, message_params: nil)
      Conversation.create(
        author: author,
        recipient: recipient(recipient_username),
        subject: subject,
      ).tap do |conversation|
        ensure_recipient(conversation: conversation, username: recipient_username)

        if conversation.persisted?
          MessageCreator.create(
            conversation: conversation,
            author: author,
            params: message_params,
          )
        end
      end
    end

    private

      def recipient(username)
        User.find_by(username: username)
      end

      def ensure_recipient(conversation:, username:)
        if conversation.recipient.nil?
          conversation.errors.add(:user, "Can't find user: #{username}")
        end
      end
  end
end
