#!/usr/bin/env perl

=head1 NAME

Local::SSHPrint - A module that provides an interface to print files to
printers over SSH

=head1 SYNOPSIS

N/A

=head1 DESCRIPTION

This is a reworking of `sshprint' ZSH script as a Perl Module.

Written by: Hans-Nikolai Viessmann (C) 2016
License: MIT
Dependencies: perl, lpr, and lpstat

=cut

package Local::SSHPrint;

our $VERSION = '2.02';

use 5.022_02;
use strict;
use utf8;
use autodie;
use warnings qw(all);

use Getopt::Long qw(:config posix_default bundling no_ignore_case);
use Pod::Usage;
use Log::Log4perl qw(:easy);
use File::Basename;
use Config::Simple;
use Net::OpenSSH;

# Ensure that the class->logger is setup.
Log::Log4perl->easy_init($WARN); 

# Declare 'global' level variables that are accessible from within the scope
# of any subroutine of this package.
use Class::Tiny qw(
  prog_name
  server
  user
  printer
  file
  lpr_options
), {
  number => 1,
  config_dir => "$ENV{'HOME'}/.config/sshprint", #FIXME change this to $prog_name, maybe?
  config_file => 'config',
  main_config => new Config::Simple(),
  sub_config => new Config::Simple(),
  logger => Log::Log4perl->get_logger()
};

# If the module is called directly as a script, we call the Main method.
# TODO: this is probably not a good design decision...
__PACKAGE__->main() unless caller();

=head2 METHODS

=cut

#-- MAIN

=head3 Main Method

=cut

sub main
{
  my $class = shift;
  $class->prog_name((fileparse($0, qr/\.[^.]*/))[0]);

  if($#ARGV lt 0)
  {
    #TODO LPR backend string...
    print("TODO: This is where we do the LPR return string for options...\n");
    exit 10;
  }

  $class->parse_args();
  
  $class->logger->debug("Entering function 'main'");
  $class->load_config();

  my $sessions = $class->main_config->param('DEFAULTS');
  my @printers = $class->sub_config->param('PRINTERS');
  my @favs = $class->sub_config->param('FAVORITEP');
  if($#printers eq 0)
  {
    print "You don't have a local copy of the printer list, retrieving...\n";
    $class->get_printer_list();

    my $response;
    print "Would you like to save the printer list in your config? [Y/n] ";
    $response = <STDIN>;
    chomp($response);

    if($response =~ /[yY]/ or $response eq "")
    {
      $class->save_config();
    }
  }

  if(!defined $class->printer())
  {
    $class->prompt_printer_input("Favorite printers: ", \@favs, \@printers);
  }

  $class->logger->debug("The follow options have been set:");
  $class->logger->debug("   SERVER = " . ($class->server() // "UNDEF"));
  $class->logger->debug("     FILE = " . ($class->file() // "UNDEF"));
  $class->logger->debug("  PRINTER = " . ($class->printer() // "UNDEF"));
  $class->logger->debug("   COPIES = " . ($class->number() // "UNDEF"));
  $class->logger->debug(" LPR_OPTS = " . join(", ", @{ $class->lpr_options() }));

  $class->print_file();
}

#-- END MAIN

=head3 Helper functions

=cut

#-- Helper Functions

=over 1

=item usage()

=cut

sub usage
{
  my $class = shift(@_);

  my $help = $class->prog_name() . " [OPTIONS...] FILE\n   or: " . $class->prog_name() . " [OPTIONS...] --file FILE";
  my $usage = <<USAGE_HERE;
Usage: $help

Options:
  -h, --help                  Print this help message and exit
  -v, --verbose               Show verbose output, specifiy multiple
                               times to increase verbosity
  -V, --version               Print version and exit
  --refresh-printers          Refresh list of printers in config  
  --list-printers             Print a list of printers
  --list-servers              Print a list of servers
  --server=SERVER             Server to connect to and print from
  --file=FILE, FILE           File to be printed

Options passed to \`lpr':
  -P printer_name             Specify printer to print to
  -n, -#, --copies=NUM        Specify number of copies
  -o, --option option[=value] Set printer option(s)

Extra:
  If verbosity is greater than 3 (i.e. `-vvv') the script will no longer
  print the specified file, instead it will print out detailed debug
  information such as options being passed over SSH to lpr.
USAGE_HERE

  print $usage;
}

# Parse Arguments
sub parse_args
{
  my $class = shift(@_);
  my $debug = 0;
  my $number = $class->number();
  my $printer;
  my $server;
  my $file;
  my @lpr_options;

  GetOptions (
    \my %opt,
    'help|h' => sub { $class->usage(); exit 0; },
    'version|V' => sub { print $class->prog_namei() . " $VERSION (Perl Edition)\n"; exit 0; },
    'verbose|v+' => \$debug, 
    'refresh-printers' => sub { $class->load_config(); $class->get_printer_list(); $class->save_config(); exit 0; },
    'list-printers' => sub { $class->load_config(); $class->get_printers(); exit 0; },
    'list-servers' => sub { $class->load_config(); $class->get_servers(); exit 0; },
    'server=s' => \$server,
    'file=s' => \$file,
    'printer|P=s' => \$printer,
    'copies|n|#=i' => \$number,
    'option|o=s' => \@lpr_options 
  );

  $class->logger->more_logging($debug);
  $class->server($server);
  $class->file($file);
  $class->printer($printer);
  $class->number($number);
  $class->lpr_options(\@lpr_options);

  if($#ARGV lt 0) 
  {
    exit 0;
  } elsif($#ARGV eq 0 and !$class->file) {
    $class->file($ARGV[0]);
  } elsif ($#ARGV eq 0 and $class->file) {
    $class->logger->logdie("Looks like you\'ve specified the file twice!");
  } elsif ($#ARGV eq 0 and !$class->file) {
    $class->logger->logdie("We should never get here!!!!");
  }

  if(%opt)
  {
    $class->logger->logdie("Oops, it looks like we don\'t support option(s): @{[keys %opt]}");
  }
}

sub load_main_config
{
  my $class = shift(@_);
  my $file = $class->config_dir() . '/'. $class->config_file();
  my $config = $class->main_config();

  if (-f not $file)
  {
    $class->logger->logdie("The config file '$file' was not found. Please create it as per https://github.com/hv15/sshprint");
  }
  
  $config->read("$file") or $class->logger->logdie("@{[$config->error()]}");
  $class->main_config($config);
}

sub load_sub_config
{
  my $class = shift(@_);
  my $config_file = shift(@_);
  my $config = $class->sub_config();

  if(!defined $config_file) {
    #TODO: need to update this to reflect changes in config file...
    if($class->main_config->param('SESSIONS')) {
      $config_file = $class->main_config->param('SESSIONS');
    } elsif($class->main_config->param('DEFAULTS')) {
      $config_file = $class->main_config->param('DEFAULTS');
    } else {
      $class->logger->logdie("No default server given, please specify a server with `-S'");
    }
  }
  my $file = $class->config_dir() . '/' . $config_file;
  
  $config->read("$file") or $class->logger->logdie("@{[Config::Simple->error()]}");
  $class->server($class->server() // $config->param("SERVER"));
  $class->sub_config($config);
}

sub load_config
{
  my $class = shift(@_);
  $class->logger->debug("Entering function 'load_config'");

  $class->load_main_config();
  $class->load_sub_config();
}

sub save_config
{
  my $class = shift(@_);
  $class->main_config->write() or $class->logger->logdie("@{[$class->main_config->error()]}");
  $class->sub_config->write() or $class->logger->logdie("@{[$class->sub_config->error()]}");
}


sub get_printers
{
  my $class = shift(@_);
  my @printers = $class->sub_config->param('PRINTERS');
  print $class->main_config->param('DEFAULTS'), ":\n";
  foreach my $printer (@printers)
  {
    print "  ", $printer, "\n";
  }
}

sub get_servers
{
  my $class = shift(@_);
  my $local_config;
  my $exclude_file = $class->config_file();
  opendir(my $dir, $class->config_dir()) or $class->logger->logdie("Unable to access " . $class->config_dir() . ". Does it exist?");
  my @files = grep {!/$exclude_file/ && !/^\./ } readdir($dir);
  foreach my $file (@files)
  {
    print $file, ":\n";
    $local_config = new Config::Simple($class->config_dir() . "/" . $file) or $class->logger->logdie("@{[Config::Simple->error()]}");
    print "  ", $local_config->param('USER'), "@", $local_config->param('SERVER'), "\n";
    $local_config->clear();
  }
  closedir $dir;
}

sub set_favorite_printers
{
  my $class = shift(@_);
  my $new_fav = shift(@_);

  if(!defined $new_fav)
  {
    $class->logger->logdie("Function `set_favorite_printers' called without an argument!");
  }

  my @favs = $class->sub_config->param('FAVORITEP');

  if(!(grep(/^$new_fav$/, @favs) ge 1))
  {
    pop(@favs);
    unshift(@favs, $new_fav);
    $class->sub_config->param('FAVORITEP', join(",", @favs));
    $class->sub_config->write();
  }
}

=item prompt_printer_input()

This function takes in a message and a list of printers and generates
a prompt for the user to select a printer from the list. The user
may also look at a complete list of printers (assuming the one
passed to the function is not the complete list).

Some sanity checking is done to ensure the user isn't making silly
selections, like `-1'.

Input:

  $class - the module class object, this is default first parameter
  $msg   - the message given before the list of printers is shown
  @favs  - this is the shortened list of the most commonly used printers
  @all   - this is the complete list of all availble printers

Output:

  None

=cut

sub prompt_printer_input()
{
  my $class = shift(@_);
  my ($msg, $favsr, $allr) = @_;
  my @favs = @{$favsr};
  my @all = @{$allr // []};

  my $bool_total;
  my $count = 0;
  my $printn = 0;
  my $printersl = $#favs + 1;

  my $select_msg = "Which printer would you like to print to? [whole list: 0, default: 1] ";
  if(!@all)
  {
    $select_msg = "Which printer would you like to print to? [default: 1] ";
    $bool_total = 1;
  }

  print "$msg:\n";
  for my $i (0 .. $#favs)
  {
    print "[",$i+1,"]: $favs[$i]\n";
  }

  for my $i (0 .. 2)
  {
    print $select_msg;
    $printn = <STDIN>;
    chomp($printn);

    if ($printn eq "") 
    {
      $printn = 1;
      last;
    } elsif ($printn eq 0 and !defined $bool_total) {
      $class->prompt_printer_input("Complete list of printers", \@all);
      return;
    } elsif ($printn =~ /[1-$printersl]/) {
      last;
    } else {
      print "Invalid printer number given ... Try again.\n";
      $count = $i;
    }
  }
  
  if($count ge 2)
  {
    $class->logger->logdie("No valid selection given.");
  }
  
  $class->printer($favs[$printn-1]);
  $class->set_favorite_printers($class->printer());
}

=back

=cut

#-- SSH Related

=head3 SSH Related functions

=over 1

=item ssh_connect()


Input:

  $class - the module class object, this is default first parameter

Output:

  $ssh - an instance of the Net::OpenSSH object

=cut

sub ssh_connect()
{
  my $class = shift(@_);
  my $login = $class->sub_config->param('USER') . "@" . $class->sub_config->param('SERVER');
  my $ssh = Net::OpenSSH->new($login)
    or $class->logger->logdie("Couldn't connect to " . $class->sub_config->param('SERVER'));

  return $ssh;
}

sub get_printer_list
{
  my $class = shift(@_);
  my $ssh = $class->ssh_connect();

  my @list = $ssh->capture({}, "lpstat -p") or 
    $class->logger->logdie("Unable to run `lpstat' command on @{[$class->sub_config->param('SERVER')]}. @{[$ssh->error]}");
  
  $class->logger->debug("@list");
  
  my @enabled_list;
  foreach my $printer (@list)
  {
    if ($printer =~ 'enabled') {
      my @words = split(' ', $printer);
      push @enabled_list, $words[1];
    }
  }
  $class->logger->debug(join(",", @enabled_list));
  $class->sub_config->param('PRINTERS', join(",", @enabled_list));
}

#TODO we need to add some debug mode so that we don't call SSH
sub print_file
{
  my $class = shift(@_);
  my $cmd = "lpr -P " . $class->printer() . " -#" . $class->number() . join(" -o ", "", @{$class->lpr_options()});
  
  if($class->logger->is_debug())
  {
    $class->logger->debug("SSH: $cmd < " . $class->file());
  } else {
    my $ssh = $class->ssh_connect();
    open(my $fh, "<", $class->file()) or $class->logger->logdie("Unable to open file: $!");
    $ssh->system({stdin_fh => $fh}, $cmd) or $class->logger->logdie("Unable to call `lpr': @{[$ssh->error()]}");
    close($fh) or $class->logger->logdie("Unable to close file: $!");
  }
}

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT

Copyright (C) 2015-2016, MIT license

=head1 AUTHOR

Hans-Nikolai Viessmann

=head1 SEE ALSO

For more information, please see the git repository at https://git.hans.ninja/hans/sshprint

=cut

# vim:ts=2:sw=2
