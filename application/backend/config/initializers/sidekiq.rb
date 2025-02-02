redis_host_name = ENV["REDIS_HOST_NAME"]
redis_post = ENV["REDIS_PORT"]
redis_url = "redis://#{redis_host_name}:#{redis_post}"

Sidekiq.configure_server do |config|
    redis_password = ENV["REDIS_PASSWORD"]
    if redis_password.present?
      config.redis = { url: redis_url, password: redis_password }
    else
      config.redis = { url: redis_url }
    end

    config.on(:startup) do
        config_file_path = "config/sidekiq-cron.yml"
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
