task :deploy do
  sh 'bundle check || bundle install'
end

task :restart do
  cfg = %x{hostname}.strip == 'web.dev' ? 'dev' : 'prod'
  begin
    sh "thin -C config/thin/#{cfg}.yaml -f stop"
  rescue
  end
  sh "thin -C config/thin/#{cfg}.yaml start"
end

task :stop do
  cfg = %x{hostname}.strip == 'web.dev' ? 'dev' : 'prod'
  sh "thin -C config/thin/#{cfg}.yaml -f stop"
end

task :run => [:deploy, :restart]
