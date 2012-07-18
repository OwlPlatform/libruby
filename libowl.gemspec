# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{libowl}
  s.version = "1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Bernhard Firner"]
  s.date = %q{2011-07-11}
  s.description = %q{The libowl network protocols are the protocols used to interact with the Owl platform or any other system that uses the GRAIL network protocols. Go to this URL for more information: http://sourceforge.net/apps/mediawiki/grailrtls/index.php?title=Category:GRAIL_RTLS_v3_Documentation}
  s.email = %q{bfirner@eden.rutgers.edu}
  #s.extensions = ["extconf.rb"]
  s.files = ["README.md", "LICENSE"]
  s.files += Dir['libowl/*.rb']
  s.files.reject! { |fname| fname.include? "test" }
  s.has_rdoc = false
  s.homepage = %q{https://github.com/OwlPlatform/libruby}
  s.require_paths = ["libowl"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Protocols for interacting with the owl platform.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
