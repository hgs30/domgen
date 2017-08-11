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

Domgen::TypeDB.config_element('graphql') do
  attr_writer :scalar_type

  def scalar_type
    @scalar_type || (Domgen.error('scalar type not defined'))
  end
end

Domgen::TypeDB.enhance(:text, 'graphql.scalar_type' => 'String')
Domgen::TypeDB.enhance(:integer, 'graphql.scalar_type' => 'Int')
Domgen::TypeDB.enhance(:long, 'graphql.scalar_type' => 'Long')
Domgen::TypeDB.enhance(:real, 'graphql.scalar_type' => 'Float')
Domgen::TypeDB.enhance(:date, 'graphql.scalar_type' => 'Date')
Domgen::TypeDB.enhance(:datetime, 'graphql.scalar_type' => 'DateTime')
Domgen::TypeDB.enhance(:boolean, 'graphql.scalar_type' => 'Boolean')

Domgen::TypeDB.enhance(:point, 'graphql.scalar_type' => 'Point')
Domgen::TypeDB.enhance(:multipoint, 'graphql.scalar_type' => 'MultiPoint')
Domgen::TypeDB.enhance(:linestring, 'graphql.scalar_type' => 'LineString')
Domgen::TypeDB.enhance(:multilinestring, 'graphql.scalar_type' => 'MultiLineString')
Domgen::TypeDB.enhance(:polygon, 'graphql.scalar_type' => 'Polygon')
Domgen::TypeDB.enhance(:multipolygon, 'graphql.scalar_type' => 'MultiPolygon')
Domgen::TypeDB.enhance(:geometry, 'graphql.scalar_type' => 'Geometry')
Domgen::TypeDB.enhance(:pointm, 'graphql.scalar_type' => 'PointM')
Domgen::TypeDB.enhance(:multipointm, 'graphql.scalar_type' => 'MultiPointM')
Domgen::TypeDB.enhance(:linestringm, 'graphql.scalar_type' => 'LineStringM')
Domgen::TypeDB.enhance(:multilinestringm, 'graphql.scalar_type' => 'MultiLineStringM')
Domgen::TypeDB.enhance(:polygonm, 'graphql.scalar_type' => 'PolygonM')
Domgen::TypeDB.enhance(:multipolygonm, 'graphql.scalar_type' => 'MultiPolygonM')

module Domgen
  FacetManager.facet(:graphql) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::JavaClientServerApplication
      include Domgen::Java::BaseJavaGenerator

      attr_writer :graphql_schema_name

      def graphql_schema_name
        @graphql_schema_name || repository.name
      end

      def scalars
        @scalars ||= []
      end

      def scalar(scalar)
        s = self.scalars
        s << scalar unless s.include?(scalar)
        s
      end

      def non_standard_scalars
        self.scalars.select{|s| !%w(Int Float Boolean String ID).include?(s)}
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::ImitJavaPackage

      attr_writer :prefix

      def prefix
        @prefix ||= data_module.name.to_s == data_module.repository.name.to_s ? '' : data_module.name.to_s
      end
    end

    facet.enhance(EnumerationSet) do
      attr_writer :name

      def name
        @name || "#{enumeration.data_module.graphql.prefix}#{enumeration.name}"
      end
    end

    facet.enhance(EnumerationValue) do
      attr_writer :name

      def name
        @name || "#{value.enumeration.data_module.graphql.prefix}#{value.name}"
      end
    end

    facet.enhance(Entity) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :name

      def name
        @name || "#{entity.data_module.graphql.prefix}#{entity.name}"
      end
    end

    facet.enhance(Attribute) do
      include Domgen::Java::ImitJavaCharacteristic

      attr_writer :name

      def name
        @name || (attribute.name.to_s.upcase == attribute.name.to_s ? attribute.name.to_s : Reality::Naming.camelize(attribute.name))
      end

      def type
        Domgen.error("Invoked graphql.type on #{attribute.qualified_name} when attribute is a remote_reference") if attribute.remote_reference?
        if attribute.reference?
          return attribute.referenced_entity.graphql.name
        elsif attribute.enumeration?
          return attribute.enumeration.graphql.name
        else
          return scalar_type
        end
      end

      attr_writer :scalar_type

      def scalar_type
        return @scalar_type if @scalar_type
        Domgen.error("Invoked graphql.scalar_type on #{attribute.qualified_name} when attribute is a non_standard_type") if attribute.non_standard_type?
        return 'ID' if attribute.primary_key?
        Domgen.error("Invoked graphql.scalar_type on #{attribute.qualified_name} when attribute is a reference") if attribute.reference?
        Domgen.error("Invoked graphql.scalar_type on #{attribute.qualified_name} when attribute is a remote_reference") if attribute.remote_reference?
        Domgen.error("Invoked graphql.scalar_type on #{attribute.qualified_name} when attribute has no characteristic_type") unless attribute.characteristic_type
        attribute.characteristic_type.graphql.scalar_type
      end


      def pre_complete
        if @scalar_type
          attribute.referenced_entity.data_module.repository.graphql.scalar(@scalar_type)
        elsif attribute.characteristic_type
          attribute.entity.data_module.repository.graphql.scalar(attribute.characteristic_type.graphql.scalar_type)
        end
      end

      protected

      def characteristic
        attribute
      end
    end

    facet.enhance(InverseElement) do
      attr_writer :name

      def name
        @name || (inverse.name.to_s.upcase == inverse.name.to_s ? inverse.name.to_s : Reality::Naming.camelize(inverse.name))
      end

      def traversable=(traversable)
        Domgen.error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
        @traversable = traversable
      end

      def traversable?
        @traversable.nil? ? (self.inverse.traversable? && self.inverse.attribute.referenced_entity.graphql?) : @traversable
      end
    end

    facet.enhance(Struct) do
      include Domgen::Java::BaseJavaGenerator
    end

    facet.enhance(StructField) do
      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        field
      end
    end
  end
end
