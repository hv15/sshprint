#!/usr/bin/env perl

=head1 NAME

Local::SSHPrint - A module that provides an interface to print files on
printers located in remote networks using ssh(1).

=head1 SYNOPSIS

  use Local::SSHPrint;
  
  # get options and set other fields...
  
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
      print "Saving...\n";
      $class->save_config();
    } else {
      warn("Moving on without saving...\n");
    }
  }

=head1 DESCRIPTION

This modules provides an interface to print a file to a printer connected to a
remote network. Principally, the script adds some extra stuff around

  ssh $USER@$REMOTEHOST "lpr -P $PRINTER" < "$DOCUMENT"

The module in addition to printing a file on a remote system, provides facilities
to handling configuration files for different systems. Each configuration file
contains stateful information like a list of all available printers on the remote
system and favorite printers based on historical use.

The functions to do this are given in section L</Methods>.

Details about the configuration file and format is given in L</"Configuration Format">

=cut

package Local::SSHPrint;

our $VERSION = '2.04';

use 5.022_02;
use strict;
use utf8;
use autodie;
use warnings qw(all);

use Log::Log4perl qw(:easy);
use Config::Simple;
use Net::OpenSSH;

# Ensure that the class->logger is setup.
Log::Log4perl->easy_init($ERROR); 

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
  config_dir => "$ENV{'HOME'}/.config/sshprint", #FIXME
  config_file => 'config',
  main_config => new Config::Simple(),
  sub_config => new Config::Simple(),
  logger => Log::Log4perl->get_logger()
};

=head2 Methods

=over 4

=item B<load_main_config>

Function loads the main configuration (usually located at
C<$HOME/.config/sshprint/config>).

Input:

  $class - class object.

Output:

  None

=cut

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

=item B<load_sub_config>

Function loads the I<sub>-configuration. If no parameter is given, the
default sub-configuration file is take from the B<DEFAULT> key in the main
configuration file.

Input:

  $class       - class object.
  $config_file - file name (I<OPTIONAL>).

Output:

  None

=cut

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

=item B<load_config>

Function loads both the main and sub- configuration files.

Input:

  $class - class object.

Output:

  None

=cut

sub load_config
{
  my $class = shift(@_);
  $class->logger->debug("Entering function 'load_config'");

  $class->load_main_config();
  $class->load_sub_config();
}

=item B<save_config>

Function saves the current state of configuration values to file.

Input:

  $class - class object.

Output:

  None

=cut

sub save_config
{
  my $class = shift(@_);
  $class->main_config->write() or $class->logger->logdie("@{[$class->main_config->error()]}");
  $class->sub_config->write() or $class->logger->logdie("@{[$class->sub_config->error()]}");
}

=item B<get_printers>

Function prints out the printer list of the sub-configuration file.

Input:

  $class  - class object.
  $server - printers to print associated with server (I<not implemented yet>).

Output:

  None

#TODO still need to implement support for arbitrary configuration file via field.

=cut

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

=item B<get_servers>

Function prints out all the servers for which there is a sub-configuration file.

Input:

  $class - class object.

Output:

  None

=cut

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
  closedir($dir);
}

=item B<check_in_config>

Function generically searches for a pattern within all sub-configuration files.

Input:

  $class   - class object.
  $phrase  - pattern to look for.
  $message - useful message to print to the user/log.

Output:

 $found    - undef => not found
                 1 => found

=cut

sub check_in_config
{
  my ($class, $phrase, $message) = @_;
  my $found;
  my $exclude_file = $class->config_file();

  opendir(my $dir, $class->config_dir()) or $class->logger->logdie("Unable to access " . $class->config_dir() . ". Does it exist?\n");
  my @files = grep {!/$exclude_file/ && !/^\./ } readdir($dir);
  foreach my $file (@files)
  {
    $class->logger->info("Opening $file");
    open(my $fh, '<', $class->config_dir() . "/$file") or $class->logger->logdie("Unable to open file `$file\'.\n");
    while (<$fh>)
    {
      if(/$phrase/)
      {
        $class->logger->info("Found $message in $file");
        $found = 1;
        last;
      }
    }
    close($fh);
  }
  closedir($dir);

  return $found;
}

=item B<check_server>

Function checks to see if a sub-configuration file exists for the given server.

Input:

  $class  - class object.
  $server - server to check for.

Output:

 $found    - undef => not found
                 1 => found

=cut

sub check_server
{
  my $class = shift(@_);
  my $server = shift(@_);
  return $class->check_in_config("SERVER=$server\$", "server `$server\'");
}

=item B<check_printer>

Function checks to see if the given printer exists within the sub-configuration.

Input:

  $class  - class object.
  $printer - printer to check for.

Output:

 $found    - undef => not found
                 1 => found

=cut

sub check_printer
{
  my $class = shift(@_);
  my $printer = shift(@_);
  return $class->check_in_config("PRINTERS=.*$printer,", "printer `$printer\'");
}

=item B<set_favorite_printers>

Function updates the favorite printer array (within the sub-configuration file
know as B<FAVORITEP>). The function only updates the array if the printer was
never used before, otherwise it is added to the front of the array, with the
last element dropped.

Input:

  $class   - class object.
  $new_fav - new favorite printer.

Output:

  None

=cut

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

=item B<prompt_printer_input>

This function takes in a message and a list of printers and generates
a prompt for the user to select a printer from the list. The user
may also look at a complete list of printers (assuming the one
passed to the function is not the complete list).

Some sanity checking is done to ensure the user isn't making silly
selections, like I<-1>.

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

=item B<ssh_connect>

Function creates a connection to the remote system.

Input:

  $class - class object.

Output:

  $ssh   - an instance of the Net::OpenSSH object.

=cut

sub ssh_connect()
{
  my $class = shift(@_);
  my $login = $class->sub_config->param('USER') . "@" . $class->sub_config->param('SERVER');
  my $ssh = Net::OpenSSH->new($login)
    or $class->logger->logdie("Couldn't connect to " . $class->sub_config->param('SERVER'));

  return $ssh;
}

=item B<printer_get_list>

Function retrieves a list of printer available on the remote system.

Input:

  $class - class object.

Output:

  None

=cut

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

=item B<print_file>

Function generates the lpr(1) command, opens an SSH connection to the
remote system, and executes the command while streaming the file.

Input:

  $class - class object.

Output:

  None

=cut

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

=head2 Configuration Format

The modules support several configuration files, all of which are located in
I<~/.config/sshprint/> by default. Any use of this modules needs to have at
least two configuration files. The I<main> configuration file to specify some
default values (called L<config>) and a I<sub> configuration file to specify
remote system related options.

The configuration files support the following keys:

=head3 Main configuration

 Key          Meaning and Use
 ---          ---------------
 DEFAULTS     This is the name of the sub configuration file that the module will
              use (REQUIRED).

=head3 Sub Configuration

 Key          Meaning and Use
 ---          ---------------
      USER    The username of the account on the remote system (REQUIRED).
    SERVER    The address of the remote system (REQUIRED).
  PRINTERS    An array of the names of printer that can be used.
 FAVORITEP    An array of the top three last used printers.

=head1 AUTHOR

Written by Hans-Nikolai Viessmann with inspiration taken from Andre Masella's
script I<sshlpr> and D. Sim (AKA xkjyeah) script I<sshlpr2>.

=head1 COPYRIGHT

Copyright (C) 2015-2016, Hans-Nikolai Viessmann. This software is licensed
under the terms of the MIT license.

=head1 SEE ALSO

L<Net::OpenSSH>, sshprint(1), sshlpr3(1), and lpr(1).

For more information, please see the git repository at L<https://git.hans.ninja/hans/sshprint>.

=cut

# vim:ts=2:sw=2
