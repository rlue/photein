Gem::Specification.new do |s|
  s.name = 'archivist'
  s.version = '0.0.1'
  s.licenses = ['MIT']
  s.required_ruby_version = '>= 2.6.0'
  s.authors = ['Ryan Lue']
  s.email = 'hello@ryanlue.com'
  s.summary = 'Import/rename photos & videos from one directory to another.'
  s.description = <<~DESC.chomp
  DESC
  s.files = ['bin/archivist']
  s.executables << 'archivist'
  s.homepage = 'https://github.com/rlue/archivist'

  s.add_dependency 'mini_exiftool', '~> 2.10'
  s.add_dependency 'mini_magick', '~> 4.11'
  s.add_dependency 'streamio-ffmpeg', '~> 3.0'
  s.metadata = { 'source_code_uri' => 'https://github.com/rlue/archivist' }
end

