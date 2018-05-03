class UnprocessableEntitySerializer < ActiveModel::Serializer
  def initialize(object, options = {})
    self.class.class_eval do
      attribute object.class.name.split('::').last.underscore.to_sym
      define_method object.class.name.split('::').last.underscore, lambda { build_errors }
    end
    super(object, options)
  end

  def build_errors
    # :messages or :details
    type = :details
    nested_errors = {}
    object.class.reflect_on_all_associations.each do |assoc|
      next unless object.class.nested_attributes_options.key?(assoc.name) && assoc.validate?
      if assoc.collection?
        object.send(assoc.name).each do |nested|
          nested_errors[assoc.name] ||= []
          nested_errors[assoc.name].push nested.errors.send(type)
        end
      else
        nested_errors[assoc.name] = object.send(assoc.name).errors.send(type)
      end
    end
    object.errors.send(type).merge(nested_errors)
  end
end
