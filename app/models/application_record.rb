# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Enable strict_loading by default for all models to catch N+1 queries
  # Can be overridden in individual models with strict_loading_mode :disabled
  strict_loading :n_plus_one
end
