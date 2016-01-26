# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = "chamois"
  spec.version       = '0.0.9'
  spec.authors       = ["Tomáš Fedor"]
  spec.email         = ["tomas.fedor3@gmail.com"]

  spec.summary       = "Chamois deployment tool"
  spec.description   = <<-EOF
    Chamois is a simple deployment tool that can deploy to multiple targets during multiple stages.
    Also allows to set up rules to tell where to deploy (or not deploy) specific files.
  EOF

#  spec.homepage      = "TODO"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.bindir        = "bin"
  spec.executables   = ['chamois', 'cham']
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "thor"
  spec.add_development_dependency "net-ssh"
  spec.add_development_dependency "net-scp"
  spec.add_development_dependency "colorize"
end
