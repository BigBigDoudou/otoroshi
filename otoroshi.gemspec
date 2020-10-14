# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name                  = 'otoroshi'
  s.version               = '0.0.6'
  s.required_ruby_version = '>= 2.6'
  s.date                  = '2020-10-10'
  s.summary               = 'Otoroshi'
  s.description           = 'Help defining class properties'
  s.authors               = ['Edouard Piron']
  s.email                 = 'ed.piron@gmail.com'
  s.files                 = Dir['{app,config,db,lib}/**/*']
  s.homepage              = 'https://rubygems.org/gems/otoroshi'
  s.license               = 'MIT'
end
