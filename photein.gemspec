require File.expand_path('./lib/photein/version', __dir__)

Gem::Specification.new do |s|
  s.name = 'photein'
  s.version = Photein::VERSION
  s.licenses = ['MIT']
  s.required_ruby_version = '>= 2.6.0'
  s.authors = ['Ryan Lue']
  s.email = 'hello@ryanlue.com'
  s.summary = 'Import/rename photos & videos from one directory to another.'
  s.description = <<~DESC.chomp
  DESC
  s.files = `git ls-files bin data lib vendor README.md`.split
  s.executables += ['photein']
  s.homepage = 'https://github.com/rlue/photein'

  s.add_dependency 'activesupport', '~> 8.0'
  s.add_dependency 'logger', '~> 1.6'
  s.add_dependency 'mediainfo', '~> 1.5'
  s.add_dependency 'mini_exiftool', '~> 2.14'
  s.add_dependency 'mini_magick', '~> 4.11'
  s.add_dependency 'nokogiri', '~> 1.11'
  s.add_dependency 'optipng', '~> 0.2'
  s.add_dependency 'ostruct', '~> 0.6'
  s.add_dependency 'pstore', '~> 0.1'
  s.add_dependency 'rexml', '~> 3.4'
  s.add_dependency 'streamio-ffmpeg', '~> 3.0'
  s.add_dependency 'tzinfo', '~> 2.0'
  s.add_dependency 'wheretz', '~> 0.0'
  s.add_development_dependency 'pry-remote', '~> 0.1'
  s.add_development_dependency 'rspec', '~> 3.10'
  s.metadata = { 'source_code_uri' => 'https://github.com/rlue/photein' }
end
