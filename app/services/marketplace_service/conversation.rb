module MarketplaceService
  module Conversation
    ConversationModel = ::Conversation

    module Entity
      Conversation = Struct.new(
        :id,
        :participants,
        :messages,
        :transaction,
        :listing
      )

      ConversationParticipant = Struct.new(
        :id,
        :username,
        :name,
        :avatar,
        :is_read,
        :is_starter
      )

      Message = Struct.new(
        :sender_id,
        :content,
        :created_at
      )

      TransactionEntity = MarketplaceService::Transaction::Entity
      Listing = TransactionEntity::Listing
      Transaction = TransactionEntity::Transaction
      Transition = TransactionEntity::Transition
      Testimonial = TransactionEntity::Testimonial

      module_function

      def conversation(conversation_model)
        h = {id: conversation_model.id}

        h[:participants] = conversation_model.participations.map do |participation|
          participant = participation.person
          EntityUtils.from_hash(ConversationParticipant, {
            id: participant.id,
            username: participant.username,
            name: participant.name,
            avatar: participant.image.url(:thumb),
            is_read: participation.is_read,
            is_starter: participation.is_starter})
        end

        h[:messages] = conversation_model.messages
          .reject { |message| message.content.blank? }
          .map { |message|
            EntityUtils.from_hash(Message, EntityUtils.model_to_hash(message))
          }

        EntityUtils.from_hash(Conversation, h)
      end

      def conversation_with_transaction(conversation_model)
        conversation_entity = conversation(conversation_model)
        conversation_entity.transaction = TransactionEntity.transaction(conversation_model.transaction) if conversation_model.transaction.present?
        conversation_entity
      end
    end

    module Command
      module_function
    end

    module Query

      module_function

      def conversations_and_transactions(person_id, community_id, pagination_opts = {})
        conversations = ConversationModel.joins(:participations)
          .where( { participations: { person_id: person_id }} )
          .where(community_id: community_id)
          .includes(:transaction)
          .order("last_message_at DESC")

        conversations = if pagination_opts[:per_page].present? && pagination_opts[:page].present?
          conversations.paginate(per_page: pagination_opts[:per_page], page: pagination_opts[:page])
        else
          conversations
        end

        conversations.map do |conversation_model|
          Entity.conversation_with_transaction(conversation_model)
        end
      end

      def conversation_for_person(conversation_id, person_id, community_id)
        conversation = ConversationModel.joins(:participations)
          .where({id: conversation_id, community_id: community_id })
          .where( { participations: { person_id: person_id }} )
          .first

        Entity.conversation_with_transaction(conversation)
      end
    end
  end
end