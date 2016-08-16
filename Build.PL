use Module::Build;

my $build = Module::Build->new
(
  module_name => 'Local::SSHPrint',
  dist_author => 'Hans-Nikolai Viessmann <hv15@hw.ac.uk>',
  license => 'open_source',
  requires => {
    'perl'           => '5.022_02',
    'Log::Log4perl'  => '>= 1.47',
    'Config::Simple' => '>= 4.56',
    'Net::OpenSSH'   => '>= 0.73',
  },
);
$build->create_build_script;

# vim:ts=2:sw=2
