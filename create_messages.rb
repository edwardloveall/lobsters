# rails runner create_messages.rb

require "faker"

TOTAL_USERS = User.count
CONVOS_PER_USER = 50
MIN_MESSAGES = 1
MAX_MESSAGES = 10

Message.delete_all

User.find_each do |user1|
  CONVOS_PER_USER.times do
    user2 = user1
    while user2 == user1 do
      user2 = User.offset(rand(TOTAL_USERS)).first
    end
    users = [user1, user2]
    messages_count = rand(MIN_MESSAGES..MAX_MESSAGES)
    subject = Faker::Lorem.sentence
    user_indexes = [0, 1].cycle

    messages_count.times.zip(user_indexes) do |message_index, author_index|
      message = Message.create(
        author: users[author_index],
        recipient: users[1 - author_index],
        subject: message_index > 0 ? "Re: #{subject}" : subject,
        body: Faker::Hacker.say_something_smart,
      )
      raise message.errors.full_messages.to_sentence if !message.persisted?
    end
  end
  print "."
end

puts
