# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = "chamois"
  spec.version       = '0.0.1'
  spec.authors       = ["Tomáš Fedor"]
  spec.email         = ["tomas.fedor3@gmail.com"]

  spec.summary       = "Chmois deployment tool"
  spec.description   = "Chmois deployment tool"
#  spec.homepage      = "TODO"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.bindir        = "bin"
  spec.executables   = ['chamois']
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake"
  spec.add_development_dependency "thor"
  spec.add_development_dependency "net-ssh"
  spec.add_development_dependency "net-scp"
  spec.add_development_dependency "colorize"
end
