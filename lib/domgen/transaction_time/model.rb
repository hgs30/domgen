#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Transaction time facet
module Domgen
  FacetManager.facet(:transaction_time) do |facet|
    facet.enhance(Attribute) do

      attr_writer :verify_reference

      def verify_reference?
        @verify_reference.nil? ? true : !!@verify_reference
      end

      def post_verify
        if verify_reference? && attribute.reference? && !attribute.referenced_entity.transaction_time? && attribute.referenced_entity.deletable?
          Domgen.error("Transaction time attribute #{attribute.qualified_name} references non-transaction time entity #{attribute.referenced_entity.qualified_name}. This is a problem when the entity is removed.")
        end
      end
    end

    facet.enhance(Repository) do
      attr_writer :supports_cascade_remove

      def supports_cascade_remove?
        @supports_cascade_remove.nil? ? true : !!@supports_cascade_remove
      end
    end

    facet.enhance(Entity) do

      attr_writer :supports_cascade_remove

      def supports_cascade_remove?
        @supports_cascade_remove.nil? ? entity.data_module.repository.transaction_time.supports_cascade_remove? : !!@supports_cascade_remove
      end

      def pre_pre_complete
        self.entity.datetime(:CreatedAt, :immutable => true) unless self.entity.attribute_by_name?(:CreatedAt)
        self.entity.datetime(:DeletedAt, :set_once => true, :nullable => true) unless self.entity.attribute_by_name?(:DeletedAt)
      end

      def post_complete
        if self.entity.jpa? && !self.entity.abstract?
          self.entity.jpa.default_jpql_criterion = 'this.deletedAt IS NULL'
          self.entity.jpa.create_default(:CreatedAt => 'now()', :DeletedAt => 'null')
          self.entity.jpa.update_default(:DeletedAt => nil)
          self.entity.jpa.update_defaults.each do |defaults|
            self.entity.jpa.update_default(defaults.values.merge(:DeletedAt => nil)) do |new_default|
              new_default.factory_method_name = defaults.factory_method_name
            end
            self.entity.jpa.remove_update_default(defaults)
          end
        end
        if self.entity.imit?
          attributes = self.entity.attributes.select {|a| %w(CreatedAt DeletedAt).include?(a.name.to_s) && a.imit?}.collect {|a| a.name.to_s}
          if attributes.size > 0
            defaults = {}
            defaults[:CreatedAt] = 'org.realityforge.guiceyloops.shared.ValueUtil.now()' if attributes.include?('CreatedAt')
            defaults[:DeletedAt] = 'null' if attributes.include?('DeletedAt')
            self.entity.imit.test_create_default(defaults)
          end
        end
      end
    end
  end
end
