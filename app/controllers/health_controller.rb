# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def sidekiq
    stats = Sidekiq::Stats.new
    latency = Sidekiq::Queue.new.latency

    if stats.processes_count == 0
      render json: { status: 'error', reason: 'No Sidekiq processes running' },
             status: :service_unavailable
    elsif latency > 300
      render json: { status: 'error', reason: "Queue latency: #{latency.to_i}s" },
             status: :service_unavailable
    else
      render json: {
        status: 'ok',
        processes: stats.processes_count,
        enqueued: stats.enqueued,
        failed: stats.failed,
        latency: latency.round(2)
      }
    end
  end
end