class SecurityReportSubscriberJob < ApplicationJob
  def perform(*args)
    puts "SecurityReportSubscriberJobが動いたよ"
    puts "args: #{args}"
  end
end
