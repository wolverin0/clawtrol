# frozen_string_literal: true

class ZerobitchMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Zerobitch::MetricsStore.collect_all
  end
end
