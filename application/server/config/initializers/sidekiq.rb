redis_host_name = ENV["REDIS_HOST_NAME"]
redis_post = ENV["REDIS_PORT"]
redis_url = "redis://#{redis_host_name}:#{redis_post}"

Sidekiq.configure_server do |config|
    config.redis = { url: redis_url }

    config.on(:startup) do
        config_file_path = Rails.env.production? ?
            "config/sidekiq.yml.production" : "config/sidekiq.yml.development"
        if File.exist?(config_file_path)
            sidekiq_configuration = YAML.load_file(config_file_path)
            job_names = sidekiq_configuration.keys
            # サーバ起動時にジョブの2重登録防止のため、登録済みジョブはいったん削除
            job_names.each do |job_name|
                job = Sidekiq::Cron::Job.find(job_name)
                job.destroy unless job.nil?
            end

            Sidekiq::Cron::Job.load_from_hash(sidekiq_configuration)
        end
    end
end

Sidekiq.configure_client do |config|
    config.redis = { url: redis_url }
end
