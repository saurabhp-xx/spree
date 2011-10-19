# *Spree::ProductScope* is model for storing named scopes with their arguments,
# to be used with Spree::ProductGroups.
#
# Each product Scope can be applied to Spree::Product (or product scope) with #apply_on method
# which returns new combined named scope
#
class Spree::ProductScope < ActiveRecord::Base
  # name
  # arguments
  belongs_to :product_group, :class_name => 'Spree::ProductGroup'
  serialize :arguments

  validate :check_validity_of_scope

  extend ::Spree::Scopes::Dynamic

  # Get all products with this scope
  def products
    if Spree::Product.respond_to?(name)
      Spree::Product.send(name, *arguments)
    end
  end

  # Applies product scope on Spree::Product model or another named scope
  def apply_on(another_scope)
    array = *self.arguments
    if Spree::Product.respond_to?(self.name.intern)
      relation2 = if (array.blank? || array.size < 2)
                      Spree::Product.send(self.name.intern, array.try(:first))
                  else
                      Spree::Product.send(self.name.intern, *array)
                  end
    else
      relation2 = Spree::Product.metasearch({self.name.intern => array}).relation
    end
    unless another_scope.class == ActiveRecord::Relation
      another_scope = another_scope.send(:relation)
    end
    another_scope.merge(relation2)
  end

  before_validation(:on => :create) {
    # Add default empty arguments so scope validates and errors aren't caused when previewing it
     if name && args = Spree::Scopes::Product.arguments_for_scope_name(name)
      self.arguments ||= ['']*args.length
    end
  }

  # checks validity of the named scope (if its safe and can be applied on Spree::Product)
  def check_validity_of_scope
    errors.add(:name, 'is not a valid scope name') unless Spree::Product.respond_to?(self.name.intern)
    apply_on(Spree::Product).limit(0) != nil
  rescue Exception => e
    unless Rails.env.production?

      puts "name: #{self.name}"
      puts "arguments: #{self.arguments.inspect}"
      puts e.message
      puts e.backtrace
    end
    errors.add(:arguments, 'are incorrect')
  end

  # test ordering scope by looking for name pattern or missed arguments
  def is_ordering?
    name =~ /^(ascend_by|descend_by)/ || arguments.blank?
  end

  def to_sentence
    result = I18n.t(:sentence, :scope => [:product_scopes, :scopes, self.name], :default => '')
    result = I18n.t(:name, :scope => [:product_scopes, :scopes, self.name]) if result.blank?
    result % [*self.arguments]
  end

  def to_s
    to_sentence
  end
end
