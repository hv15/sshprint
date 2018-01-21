SSHPrint
========

This is a small Perl script I created to quickly print something to a printer
connected to a remote network. Principally, the script adds some extra stuff
around

```sh
ssh $USER@$REMOTEHOST "lpr -P $PRINTER" < "$DOCUMENT"
```

such as providing a list of available printers (using `lpstat -p`) as well as
using a configuration files to setup some things (username and server
address for one as well as store a list of printers for quick and easy
selection). Additionally printer options (`lpr -o ...`) can be specified as
well as the number copies wanted.

`sshprint` can now interact with multiple servers, each with its own
configurations. A user can specify which one they want through both a command
line argument or config key.

Manual
------

In order to use the script, you need to have [Perl](http://www.perl.org/) and
OpenSSH `ssh`. Additionally, the remote server needs to have the `lpr` and
`lpstat` programs installed and access to at least one printer.

More information on how to use `sshprint` or even the `Local::SSHPrint` module
can be read up in their respective manpages.

### Installation

#### General

I've decided to use the [BUILD.PL](http://search.cpan.org/perldoc?Module%3A%3ABuild)
to *build* and install the Perl module and script file(s). Here are the basic steps:

```sh
# build
$ perl BUILD.PL installdir=vendor
$ perl Build

# install
$ perl Build install
```

Example configuration files as well as documentation can be copied over to the
correct directories (usually under `/usr`).

#### *ArchLinux*

For those running on ArchLinux, I've created a PKGBUILD script which you can
use to generate the package, or if you use `yaourt`/`pacaur`, you can get the
package straight from the [AUR](https://aur.archlinux.org/packages/sshprint/).

#### Dependencies

* Perl 5.22 or greater
* `Log::Log4Perl` module
* `Config::Simple` module
* `Net::OpenSSH` module
* CUPS (`lpr` and `lpstat`)
* OpenSSH (`ssh`)

### Config

`sshprint` supports several config files, all of which are located in
`~/.config/sshprint/` by default. Any setup of `sshprint` needs to have at
least two config files. The main config file to specify some\* default values
(called `config`) and a server config file to specify server related options.
The config files support the following keys:

#### Keys for `config` file

| Key        | Meaning and Use                                                                                                      |
|------------|----------------------------------------------------------------------------------------------------------------------|
| `default` | This is the name of the server config file that `sshprint` will use if none is given by command line (**REQUIRED**)  |

#### Keys for Server config file

| Key         | Meaning and Use                                                                |
|-------------|--------------------------------------------------------------------------------|
| `user`      | The username of the account  on the remote server (**REQUIRED**)               |
| `server`    | The address of the remote server (**REQUIRED**)                                |
| `printers`  | An array of the names of printer that can be used (*generated at initial run*) |
| `favoritep` | An array of the top three last used printers (*generated at each run*)         |

An example of a typical server config file is given below:

**These file are not initialised or created by the script at first use, the
user needs to create it themselves**. I have now provided an example of the
config file as part of this repo, it should be enough to get started. The
config file is loaded at each call of `sshprint` and the variables are sourced
and used directly in the script. *No checks are performed to ensure sane
formating or validity of keys*.

### Usage

```text
Usage:
    sshprint [OPTION]... [--file] FILE

Options:
    -h, --help
        Print this help message and exit.

    -v, --verbose
        Show verbose output - specify multiple times to increase verbosity.

    -V, --version
        Print version and exit.

    --refresh-printers
        Refresh list of printers in configuration file. May be combined with
        --server to specify which configuration file to update, otherwise
        the default one is used.

    --list-printers
        Print a list of printers for each configuration file.

    --list-servers
        Print a list of remote systems for which we have a configuration
        file.

    --server server
        Remote system to connect to and print from.

    --file file
        File to be printed. This can either be specified as the last
        argument or through this flag. The flag has precedence.

  Options passed to lpr(1):
    -P printer_name
        Specify printer to print to.

    -n, -#, --copies number
        Specify number of copies - must be greater than 0.

    -o, --option option[=value]
        Set printer job option - may be given multiple times. The same job
        options are supported as those of the lpr(1) -o flag.

  Extra:
    If verbosity is greater than 3 (i.e. -vvv) the script will no longer
    print the specified file, instead it will print out detailed debug
    information such as options being passed over ssh(1) to lpr(1).
```

Further Work
------------

A few extensions I'd like to add:

* improve existing server config files to include meta-data about printers
  like last time the user used them, whether their colour or mono, etc.)
* an easy setup script to generate all the config in one go as part of the
  installation/setup process

Warranty and License
--------------------

Warranty: none given... plus I can guarantee that something is amiss with my
script (issue reports welcome!). This script is licensed under the MIT
license.
