class SecurityReportSubscriberJob < ApplicationJob
  def perform(*args)
    Rails.logger.info "SecurityReportSubscriberJob started!"
    SecurityReport::SubscriberService.subscribe(from_date: Time.zone.yesterday)
  end
end
