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
            # ymlをcron登録の唯一の正とする: 全ジョブを削除してから登録し直す。
            # yml掲載分だけを削除する方式だと、ymlから外したジョブがRedisに残って
            # 永久に実行され続けてしまう（2重登録防止も兼ねる）
            Sidekiq::Cron::Job.all.each(&:destroy)
            Sidekiq::Cron::Job.load_from_hash(sidekiq_configuration)
        end
    end
end

Sidekiq.configure_client do |config|
    config.redis = { url: redis_url }
end
