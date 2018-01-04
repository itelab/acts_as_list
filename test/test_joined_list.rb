require 'helper'

class Section < ActiveRecord::Base
  has_many :items
  acts_as_list

  scope :visible, -> { where(visible: true) }
end

class Item < ActiveRecord::Base
  belongs_to :section
  acts_as_list scope: :section

  scope :visible, -> { where(visible: true).joins(:section).merge(Section.visible) }
end

class JoinedTestCase < Minitest::Test
  def setup
    ActiveRecord::Base.connection.create_table :sections do |t|
      t.column :position, :integer
      t.column :visible, :boolean, default: true
    end

    ActiveRecord::Base.connection.create_table :items do |t|
      t.column :position, :integer
      t.column :section_id, :integer
      t.column :visible, :boolean, default: true
    end

    ActiveRecord::Base.connection.schema_cache.clear!
    [Section, Item].each(&:reset_column_information)
    super
  end

  def teardown
    teardown_db
    super
  end
end

class JoinedIndexTestCase < MiniTest::Test
  def setup
    ActiveRecord::Base.connection.create_table :sections do |t|
      t.column :position, :integer
      t.column :visible, :boolean, default: true

      t.index :position, unique: true
    end

    ActiveRecord::Base.connection.create_table :items do |t|
      t.column :position, :integer
      t.column :section_id, :integer
      t.column :visible, :boolean, default: true

      t.index %I[section_id position], unique: true
    end

    ActiveRecord::Base.connection.schema_cache.clear!
    [Section, Item].each(&:reset_column_information)
    super
  end

  def teardown
    teardown_db
    super
  end
end

class TestInsertionWithIndex < JoinedIndexTestCase
  def test_update_at_position
    section = Section.create

    Item.create section: section
    Item.create section: section
    item3 = Item.create section: section

    assert_equal item3.insert_at(1), true
  end
end

# joining the relation returned by `#higher_items` or `#lower_items` to another table
# previously could result in ambiguous column names in the query
class TestHigherLowerItems < JoinedTestCase
  def test_higher_items
    section = Section.create
    item1 = Item.create section: section
    item2 = Item.create section: section
    item3 = Item.create section: section
    assert_equal item3.higher_items.visible, [item2, item1]
  end

  def test_lower_items
    section = Section.create
    item1 = Item.create section: section
    item2 = Item.create section: section
    item3 = Item.create section: section
    assert_equal item1.lower_items.visible, [item2, item3]
  end
end
