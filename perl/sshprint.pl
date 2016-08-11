#!/usr/bin/env perl
# This is a reworking of `sshprint' ZSH script in PERL...
#
# This is a little hackish script to print stuff to CUPS printers
# from anywhere ...
#
# Written by: Hans-Nikolai Viessmann (C) 2016
# License: MIT
# Dependencies: perl, lpr, and lpstat

use Modern::Perl 2015; # Do we need? Replace with strict...
use autodie;
use Const::Fast;
use File::Basename;
use Getopt::Long qw( :config posix_default bundling no_ignore_case);
use Config::Simple;
use Net::OpenSSH;

#-- Constants
const my %PROG_DATA => (
  name => (fileparse($0, qr/\.[^.]*/))[0],
  version => '1.6.4',
  config_dir => "$ENV{'HOME'}/.config/sshprint", #FIXME
  config_file => "config"
);
const my $HELP => "$PROG_DATA{name} [OPTIONS...] FILE\n   or: $PROG_DATA{name} [OPTIONS...] --file FILE";
const my $USAGE => <<USAGE_HERE;
Usage: $HELP

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

#-- Constant Psuedo-Hashes
## print related constants
use constant {
  ERROR => 0,
  WARN => 1,
  VERBOSE => 2,
  DEBUG => 3
};
use constant PRINT_TYPE => qw(ERROR WARN VERBOSE DEBUG);

#-- Globals
#FIXME we need to no use so many globals...
my @args = ();
my $file = '';
my $debug = ERROR;
my $number = 1;
my $printer = '';
my @lpr_options = ();
my $server = '';
my $sessions = '';
my @printers = ();
my @fav_printers = ();

## config related
my $main_config;
my $sub_config;

#-- MAIN

parse_args();
load_config();

$sessions = $main_config->param('DEFAULTS');
@printers = $sub_config->param('PRINTERS');
if($#printers eq 0)
{
  print "You don't have a local copy of the printer list, retrieving...\n";
  get_printer_list();
  
  my $response;
  print "Would you like to save the printer list in your config? [Y/n] ";
  $response = <STDIN>;
  chomp($response);

  if($response =~ /[yY]/ or $response eq "")
  {
    save_config();
  }
}

if($printer eq "")
{
  select_printer();
}

xprint(DEBUG, "The follow options have been set:\n" .
  "         DEBUG = @{[$debug]}\n" .
  "         SERVER = @{[$server]}\n" .
  "         FILE = @{[$file]}\n" .
  "         PRINTER = @{[$printer]}\n" .
  "         COPIES = @{[$number]}\n" .
  "         LPR_OPTS = @{[@lpr_options]}"
);

print_file();

#-- END MAIN

#-- Helper Functions

# Debug Print
sub xprint
{
  my ($pri, $msg) = @_;
  my $m = "[@{[(PRINT_TYPE)[$pri]]}]: $msg\n";
  if ($pri eq ERROR) {
    die $m;
  } elsif ($debug ge $pri) {
    warn $m;
  }
}

# Parse Arguments
sub parse_args
{
  if($#ARGV lt 0)
  {
    #TODO LPR backend string...
    die "TODO: This is where we do the LPR return string for options...\n";
  }

  GetOptions (
    \my %opt,
    'help|h' => sub { print $USAGE },
    'version|V' => sub { print "$PROG_DATA{name} $PROG_DATA{version}\n" },
    'verbose|v+' => \$debug, 
    'refresh-printers' => sub { load_config(); get_printer_list(); save_config() },
    'list-printers' => sub { load_config(); get_printers() },
    'list-servers' => sub { load_config(); get_servers() },
    'server=s' => \$server,
    'file=s' => \$file,
    'printer|P=s' => \$printer,
    'copies|n|#=i' => \$number,
    'option|o=s' => \@lpr_options 
  );

  if($#ARGV lt 0) 
  {
    exit 0;
  } elsif($#ARGV eq 0 and !$file) {
    $file = $ARGV[0];
  } elsif ($#ARGV eq 0 and $file) {
    xprint(ERROR, "Looks like you\'ve specified the file twice!");
  } elsif ($#ARGV eq 0 and !$file) {
    xprint(ERROR, "We should never get here!!!!");
  }


  if(%opt)
  {
    xprint(ERROR, "Oops, it looks like we don\'t support option(s): @{[keys %opt]}");
  }
}

sub load_main_config
{
  if (-f not "$PROG_DATA{config_dir}/$PROG_DATA{config_file}") {
    xprint(ERROR, "There is not `$PROG_DATA{config_file}' file in $PROG_DATA{config_dir}...Aborting!\n" .
      "Please create it. See https://github.com/hv15/sshprint for more information.\n");
  }
  
  $main_config = new Config::Simple("$PROG_DATA{config_dir}/$PROG_DATA{config_file}") or xprint(ERROR, "@{[Config::Simple->error()]}");
}

sub load_sub_config
{
  my $defaults = shift(@_);

  if(!defined $defaults) {
    if($main_config->param('SESSIONS')) {
      $defaults = $main_config->param('SESSIONS');
    } elsif($main_config->param('DEFAULTS')) {
      $defaults = $main_config->param('DEFAULTS');
    } else {
      xprint(ERROR, "No default server given, please specify a server with -S...Aborting!");
    }
  }
  
  $sub_config = new Config::Simple("$PROG_DATA{config_dir}/$defaults") or xprint(ERROR, "@{[Config::Simple->error()]}");
}

sub load_config
{
  load_main_config();
  load_sub_config();
}

sub save_config
{
  $main_config->write() or xprint(ERROR, "@{[$main_config->error()]}");
  $sub_config->write() or xprint(ERROR, "@{[$sub_config->error()]}");
}

sub get_printer_list
{
  my $ssh = Net::OpenSSH->new("@{[$sub_config->param('USER')]}@@{[$sub_config->param('SERVER')]}");
  xprint(ERROR, "Couldn't connect to @{[$sub_config->param('SERVER')]}! @{[$ssh->error]}") if $ssh->error;
  my @list = $ssh->capture({}, "lpstat -p");
  xprint(ERROR, "Unable to run `lpstat' command on @{[$sub_config->param('SERVER')]}. @{[$ssh->error]}") if $ssh->error;
  
  xprint(DEBUG, @list);
  
  my @enabled_list;
  foreach my $printer (@list)
  {
    if ($printer =~ 'enabled') {
      my @words = split(' ', $printer);
      push @enabled_list, $words[1];
    }
  }
  xprint(DEBUG,join(",", @enabled_list) . "\n");
  $sub_config->param('PRINTERS', join(",", @enabled_list));
}

sub get_printers
{
  my @printers = $sub_config->param('PRINTERS');
  print $main_config->param('DEFAULTS'), ":\n";
  foreach my $printer (@printers)
  {
    print "  ", $printer, "\n";
  }
}

sub get_servers
{
  my $local_config;
  opendir(my $dir, "$PROG_DATA{config_dir}") or xprint(ERROR, "Unable to access $PROG_DATA{config_dir}. Does it exist?");
  my @files = grep {!/$PROG_DATA{config_file}/ && !/^\./ } readdir($dir);
  foreach my $file (@files)
  {
    print $file, ":\n";
    $local_config = new Config::Simple("$PROG_DATA{config_dir}/$file") or xprint(ERROR, "@{[Config::Simple->error()]}");
    print "  ", $local_config->param('USER'), "@", $local_config->param('SERVER'), "\n";
    $local_config->clear();
  }
  closedir $dir;
}

sub set_favorite_printers
{
  my $new_fav = shift(@_);

  if(!defined $new_fav)
  {
    xprint(ERROR, "Function `set_favorite_printers' called without an argument!");
  }

  my @favs = $sub_config->param('FAVORITEP');

  if(!(grep(/^$new_fav$/, @favs) ge 1))
  {
    pop(@favs);
    unshift(@favs, $new_fav);
    $sub_config->param('FAVORITEP', join(",", @favs));
    $sub_config->write();
  }
}

sub all_select_printer
{
  my $count = -1;
  my $printn;

  print "Complete list of printers:\n";
  my @printers = $sub_config->param('PRINTERS');
  for my $i (0 .. $#printers)
  {
    printf "[%2s]: %s\n", $i+1, $printers[$i];
  }

  for my $i (0 .. 2)
  {
    print "Which printer would you like to print to? ";
    $printn = <STDIN>;
    chomp($printn);

    if ($printn =~ /[1-9]+/)
    {
      if($printers[$printn-1]) { last; } 
    } else {
      print "Invalid printer number given ... Try again.\n";
      $count = $i;
    }
  }

  if($count ge 2)
  {
    xprint(ERROR, "No valid selection given... Aborting!");
  }
  
  $printer = $printers[$printn-1];
  set_favorite_printers($printer);
}

#FIXME OMG WTF is this, did I actually write this....
# this needs to be refactored ASAP!!!
sub select_printer
{
  my $count = -1;
  my $printn;
  my @favs = $sub_config->param('FAVORITEP');
  my @printers = $sub_config->param('PRINTERS');

  if($#favs eq 0)
  {
    @favs = @printers[0 .. 2];  
  }

  my $favsl = $#favs + 1;
  
  print "Favorite printers:\n";
  for my $i (0 .. $#favs)
  {
    print "[",$i+1,"]: $favs[$i]\n";
  }

  for my $i (0 .. 2)
  {
    print "Which printer would you like to print to? [whole list: 0, default: 1] ";
    $printn = <STDIN>;
    chomp($printn);

    if ($printn eq "") 
    {
      $printn = 1;
      last;
    } elsif ($printn eq 0) {
      all_select_printer();
      return;
    } elsif ($printn =~ /[1-$favsl]/) {
      last;
    } else {
      print "Invalid printer number given ... Try again.\n";
      $count = $i;
    }
  }

  if($count ge 2)
  {
    xprint(ERROR, "No valid selection given... Aborting!");
  }
  
  $printer = $favs[$printn-1];
  set_favorite_printers($printer);
}

#TODO we need to add some debug mode so that we don't call SSH
sub print_file
{
  my $ssh = Net::OpenSSH->new("@{[$sub_config->param('USER')]}@@{[$sub_config->param('SERVER')]}")
    or xprint(ERROR, "Couldn't connect to @{[$sub_config->param('SERVER')]}!");
  my $cmd = "lpr -P $printer -#$number" . join(" -o ", "", @lpr_options);

  if($debug ge DEBUG)
  {
    xprint(DEBUG, "$cmd < $file");
  } else {
    open(my $fh, "<", $file) or xprint(ERROR, "Unable to open file: $!");
    $ssh->system({stdin_fh => $fh}, $cmd) or xprint(ERROR, "Unable to call `lpr': @{[$ssh->error()]}");
    close($fh) or xprint(ERROR, "Unable to close file: $!");
  }
}

# vim:ts=2:sw=2
