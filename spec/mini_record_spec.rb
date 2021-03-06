require File.expand_path('../spec_helper.rb', __FILE__)
require File.expand_path('../models.rb', __FILE__)

describe MiniRecord do

  it 'has #schema inside model' do
    # For unknown reason separate specs doesn't works
    ActiveRecord::Base.connection.table_exists?(Person.table_name).must_equal false
    Person.auto_upgrade!
    Person.table_name.must_equal 'people'
    Person.db_columns.sort.must_equal %w[created_at id name updated_at]
    Person.column_names.sort.must_equal Person.db_columns.sort
    Person.column_names.sort.must_equal Person.schema_columns.sort
    person = Person.create(:name => 'foo')
    person.name.must_equal 'foo'
    proc { person.surname }.must_raise NoMethodError

    # Test the timestamp columns exist
    person.must_respond_to :created_at
    person.must_respond_to :updated_at

    # Add a column without lost data
    Person.class_eval do
      schema do |p|
        p.string :name
        p.string :surname
      end
    end
    Person.auto_upgrade!
    Person.count.must_equal 1
    person = Person.last
    person.name.must_equal 'foo'
    person.surname.must_be_nil
    person.update_attribute(:surname, 'bar')
    Person.db_columns.sort.must_equal %w[id name surname]
    Person.column_names.must_equal Person.db_columns

    # Remove a column without lost data
    Person.class_eval do
      schema do |p|
        p.string :name
      end
    end
    Person.auto_upgrade!
    person = Person.last
    person.name.must_equal 'foo'
    proc { person.surname }.must_raise NoMethodError
    Person.db_columns.sort.must_equal %w[id name]
    Person.column_names.must_equal Person.db_columns
    Person.column_names.must_equal Person.schema_columns

    # Change column without lost data
    Person.class_eval do
      schema do |p|
        p.text :name
      end
    end
    person = Person.last
    person.name.must_equal 'foo'
  end

  it 'has #key,col,property,attribute inside model' do
    ActiveRecord::Base.connection.table_exists?(Post.table_name).must_equal false
    ActiveRecord::Base.connection.table_exists?(Category.table_name).must_equal false
    Post.auto_upgrade!; Category.auto_upgrade!
    Post.column_names.sort.must_equal Post.db_columns
    Category.column_names.sort.must_equal Category.schema_columns

    # Check default properties
    category = Category.create(:title => 'category')
    post = Post.create(:title => 'foo', :body => 'bar', :category_id => category.id)
    post = Post.first
    post.title.must_equal 'foo'
    post.body.must_equal 'bar'
    post.category.must_equal category


    # Remove a column
    Post.reset_table_definition!
    Post.class_eval do
      col :name
      col :category, :as => :references
    end
    Post.auto_upgrade!
    post = Post.first
    post.name.must_be_nil
    post.category.must_equal category
    post.wont_respond_to :title
  end

  it 'has indexes inside model' do
    # Check indexes
    Animal.auto_upgrade!
    Animal.db_indexes.size.must_be :>, 0
    Animal.db_indexes.must_equal Animal.indexes.keys.sort

    indexes_was = Animal.db_indexes

    # Remove an index
    Animal.indexes.delete(indexes_was.pop)
    Animal.auto_upgrade!
    Animal.indexes.keys.sort.must_equal indexes_was
    Animal.db_indexes.must_equal indexes_was

    # Add a new index
    Animal.class_eval do
      col :category, :as => :references, :index => true
    end
    Animal.auto_upgrade!
    Animal.db_columns.must_include "category_id"
    Animal.db_indexes.must_equal((indexes_was << "index_animals_on_category_id").sort)
  end

  it 'works with STI' do
    class Dog < Pet; end
    class Cat < Pet; end
    Pet.auto_upgrade!

    # Check inheritance column
    Pet.db_columns.wont_include "type"
    Dog.auto_upgrade!
    Pet.db_columns.must_include "type"

    # Now, let's we know if STI is working
    Pet.create(:name => "foo")
    Dog.create(:name => "bar")
    Dog.count.must_equal 1
    Dog.first.name.must_equal "bar"
    Pet.count.must_equal 2
    Pet.all.map(&:name).must_equal ["foo", "bar"]

    # Check that this doesn't break things
    Cat.auto_upgrade!
    Dog.first.name.must_equal "bar"

    # What's happen if we change schema?
    Dog.table_definition.must_equal Pet.table_definition
    Dog.indexes.must_equal Pet.indexes
    Dog.class_eval do
      col :bau
    end
    Dog.auto_upgrade!
    Pet.db_columns.must_include "bau"
    Dog.new.must_respond_to :bau
    Cat.new.must_respond_to :bau
  end

  it 'works with custom inheritance column' do
    class User < ActiveRecord::Base
      col :name
      col :surname
      col :role
      set_inheritance_column :role
    end
    class Administrator < User; end
    class Customer < User; end

    User.auto_upgrade!
    Administrator.create(:name => "Davide", :surname => "D'Agostino")
    Customer.create(:name => "Foo", :surname => "Bar")
    Administrator.count.must_equal 1
    Administrator.first.name.must_equal "Davide"
    Customer.count.must_equal 1
    Customer.first.name.must_equal "Foo"
    User.count.must_equal 2
    User.first.role.must_equal "Administrator"
    User.last.role.must_equal "Customer"
  end

  it 'allow multiple columns definitions' do
    class Fake < ActiveRecord::Base
      col :name, :surname
      col :category, :group, :as => :references
    end
    Fake.auto_upgrade!
    Fake.create(:name => 'foo', :surname => 'bar', :category_id => 1, :group_id => 2)
    fake = Fake.first
    fake.name.must_equal 'foo'
    fake.surname.must_equal 'bar'
    fake.category_id.must_equal 1
    fake.group_id.must_equal 2
  end
end
