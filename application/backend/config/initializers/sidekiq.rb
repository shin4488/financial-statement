# server（Sidekiqプロセス）とclient（ジョブを積むRails側）で接続設定を揃える。
# 片方だけパスワードを渡し忘れると、REDIS_PASSWORDのある環境でenqueueだけがNOAUTHで失敗する
redis_options = {
  url: "redis://#{ENV["REDIS_HOST_NAME"]}:#{ENV["REDIS_PORT"]}"
}
redis_options[:password] = ENV["REDIS_PASSWORD"] if ENV["REDIS_PASSWORD"].present?

Sidekiq.configure_server do |config|
    config.redis = redis_options

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
    config.redis = redis_options
end
