class SandboxTask < ApplicationJob
    def perform(*args)
        puts "sidekiq-cronが動いたよ"
        puts "args: #{args}"
        puts "name: #{args[0]["name"]}, count: #{args[0]["count"]}"
    end
end
