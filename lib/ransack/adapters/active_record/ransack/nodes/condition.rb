module Ransack
  module Nodes
    class Condition

      def arel_predicate
        attributes.map { |attribute|
          association = attribute.parent
          if negative? && attribute.associated_collection?
            query = context.build_correlated_subquery(association)
            context.remove_association(association)
            value = format_predicate(attribute).try(:right).try(:val)
            query.where(format_predicate(attribute).not)
            if attribute.name === 'labels_name'
              result_query = "SELECT \"user_tags\".\"user_id\" from \"user_tags\" where \"user_tags\".\"tag_id\" IN (SELECT \"tags\".\"id\" from \"tags\" where \"tags\".\"name\" = '#{value}')"
            else
              result_query = query.to_sql
            end
            Arel::Nodes::NotIn.new(context.primary_key, Arel.sql(result_query))
          else
            format_predicate(attribute)
          end
        }.reduce(combinator_method)
      end

      private

        def combinator_method
          combinator === Constants::OR ? :or : :and
        end

        def format_predicate(attribute)
          arel_pred = arel_predicate_for_attribute(attribute)
          if attribute.name === "labels_name"
            arel_values = formatted_values_for_tags_attribute(attribute)
          else
            arel_values = formatted_values_for_attribute(attribute)
          end
          predicate = attribute.attr.public_send(arel_pred, arel_values)

          if in_predicate?(predicate)
            predicate.right = predicate.right.map do |predicate|
              casted_array?(predicate) ? format_values_for(predicate) : predicate
            end
          end

          predicate
        end

        def in_predicate?(predicate)
          return unless defined?(Arel::Nodes::Casted)
          predicate.class == Arel::Nodes::In
        end

        def casted_array?(predicate)
          predicate.respond_to?(:val) && predicate.val.is_a?(Array)
        end

        def format_values_for(predicate)
          predicate.val.map do |value|
            value.is_a?(String) ? Arel::Nodes.build_quoted(value) : value
          end
        end

    end
  end
end
