Pod::Spec.new do |s|
  s.name         = 'HTMLReader'
  s.version      = '0.9.2'
  s.summary      = "A WHATWG-compliant HTML parser in Objective-C."
  s.homepage     = 'https://github.com/nolanw/HTMLReader'
  s.license      = "Public domain"
  s.author       = { "Nolan Waite" => 'nolan@nolanw.ca' }
  s.source       = { :git => 'https://github.com/nolanw/HTMLReader.git', :tag => "v#{s.version}" }
  s.source_files = "Code"
  s.requires_arc = true
  
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
  s.watchos.deployment_target = '2.0'
  s.tvos.deployment_target = '9.0'
end
