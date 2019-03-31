class CreateConversations < ActiveRecord::Migration[5.2]
  def change
    create_table :conversations do |t|
      t.timestamps
      t.string :short_id, null: false, unique: true
      t.string :subject, null: false
      t.belongs_to :author_user, null: false
      t.belongs_to :recipient_user, null: false
    end

    add_belongs_to :messages, :conversation, null: true

    MessageConverter.run
  end
end

class MessageConverter
  def run
    config = ActiveRecord::Base.configurations[Rails.env].symbolize_keys
    mysql = Mysql2::Client.new(config)
    connection = ApplicationRecord.connection
    connection.transaction do
      messages = mysql.query <<~SQL
        SELECT *,
        (CASE WHEN author_user_id < recipient_user_id
          THEN CONCAT(author_user_id, '-', recipient_user_id)
          ELSE CONCAT(recipient_user_id, '-', author_user_id)
        END) AS partners
        FROM messages
      SQL
      grouped = messages.group_by do |message|
        message["subject"].sub(/Re: /, '') + message["partners"]
      end
      conversation_values = grouped.map do |group|
        values = message_values(group.last, connection).join(",")
        "(#{values})"
      end.join(",\n")

      mysql.query <<~SQL
        INSERT INTO conversations
        (created_at, updated_at, short_id, subject, author_user_id, recipient_user_id)
        VALUES #{conversation_values}
      SQL

      grouped.map do |group|
        message_ids = group.last.map { |message| message["id"] }.join(", ")
        conversation_ids = mysql.query <<~SQL
          SELECT id FROM conversations
          WHERE short_id = #{message_values(group.last, connection)[2]}
        SQL
        mysql.query <<~SQL
          UPDATE messages
          SET conversation_id = #{conversation_ids.first["id"]}
          WHERE id IN (#{message_ids})
        SQL
      end
    end
  end

  def message_values(messages, connection)
    [
      connection.quote(messages.first["created_at"]),
      connection.quote(messages.last["created_at"]),
      connection.quote(messages.first["short_id"]),
      connection.quote(messages.first["subject"]),
      messages.first["author_user_id"],
      messages.first["recipient_user_id"],
    ]
  end
end
