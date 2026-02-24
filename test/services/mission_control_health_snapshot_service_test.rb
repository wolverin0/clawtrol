# frozen_string_literal: true

require "test_helper"

class MissionControlHealthSnapshotServiceTest < ActiveSupport::TestCase
  test "returns unknown pending migration status when database is disconnected" do
    fake_connection = Object.new
    fake_connection.define_singleton_method(:active?) { false }
    fake_connection.define_singleton_method(:migration_context) do
      raise "migration context should not be called when db is disconnected"
    end

    ActiveRecord::Base.stub(:connection, fake_connection) do
      snapshot = MissionControlHealthSnapshotService.call

      assert_equal false, snapshot[:database_connected]
      assert_nil snapshot[:pending_migrations]
    end
  end

  test "returns pending migration status when database is connected" do
    fake_migration_context = Object.new
    fake_migration_context.define_singleton_method(:needs_migration?) { true }

    fake_connection = Object.new
    fake_connection.define_singleton_method(:active?) { true }
    fake_connection.define_singleton_method(:migration_context) { fake_migration_context }

    ActiveRecord::Base.stub(:connection, fake_connection) do
      snapshot = MissionControlHealthSnapshotService.call

      assert_equal true, snapshot[:database_connected]
      assert_equal true, snapshot[:pending_migrations]
    end
  end
end
