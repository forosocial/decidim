# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def sidekiq
    stats = Sidekiq::Stats.new
    latency = Sidekiq::Queue.new.latency
    processes = Sidekiq::ProcessSet.new.size

    if processes == 0
      render json: { status: 'error', reason: 'No Sidekiq processes running' },
             status: :service_unavailable
    elsif latency > 300
      render json: { status: 'error', reason: "Queue latency: #{latency.to_i}s" },
             status: :service_unavailable
    else
      render json: {
        status: 'ok',
        processes: processes,
        enqueued: stats.enqueued,
        failed: stats.failed,
        latency: latency.round(2)
      }
    end
  end
end