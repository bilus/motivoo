Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'motivoo'
  s.version = '0.3'
  s.summary = 'Motivoo - AARRR Rack middleware.'
  s.description = ''

  s.author = 'Martin Bilski'
  s.email = 'gyamtso@gmail.com'
  s.homepage = 'https://github.com/bilus/motivoo'

  s.add_dependency('rack')
  s.add_dependency('mongo')
  s.add_dependency('bson_ext')

  s.files = Dir['README.md', 'MIT-LICENSE', 'lib/**/*', 'spec/**/*']
  s.has_rdoc = false

  s.require_path = 'lib'
end