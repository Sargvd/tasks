require 'zlib'

get '/js/:file.js' do
  js  = File.join(settings.coffee[:views], "#{params[:file]}.js")
  if File.exist? js
    expires 3600, :public, :must_revalidate
    send_file js
  else
    coffee params[:file].to_sym
  end
end

get('/css/:file.css') do
  css = File.join(settings.sass[:views], "#{params[:file]}.css")
  if File.exist? css
   send_file css
  else
    begin
      sass params[:file].to_sym
    rescue Errno::ENOENT
      halt [404, 'Layout not found']
    end
  end
end

get '/img/:file' do
  send_file File.join(settings.public_folder, 'img', params[:file])
end