Perl Alternative
----------------

I've decided to re-implement sshprint in PERL.

Why?
====

After using the `sshprint' script for some time now, I've realised that using
ZSH was not the wisest choice for the following reasons:

- ZSH, as awesome as it is, is not commonly available *pre-installed* on most
  GNU/Linux distros, let alone on Mac OS X. These means that users have to
  explicitly install it --- Perl is usually pre-installed.
- ZSH scripting, is well --- shell scripting, which is always a bit like
  'hammering a square peg into a round hole' at times --- it requires enginuity
  and a good understanding of the typical UNIX/GNU tools to get things done.
- With shell scripting, you tend to have the re-invent the wheel each time.
  Modularity is not it's strongsuit.

And now onto why PERL (and not Python, Ruby, or even C)? To be honest, I would
like to write this app in C --- actually I'd love to create a two-in-one sort of
app that could work directly with the `lpr' like `sshlpr2' attempts and also
work as standalone (for systems with no printer server setup). But I don't have
the time at the moment to really give my complete focus to that goal --- I can achieve
the same effect with PERL.

Change Log
==========

## [Unreleased - dubbed 1.6.4]
### **Major Changes**
- Moved from ZSH to PERL
- Dropped the `beta' postfix from the version number
- Started using some modules, like Config::Simple and Net::OpenSSH to deal with
  accessing configurations and handling SSH connections respectively.
### **Known Problems**
- Currently untested
### **Still to do**
- PERL opens up the possibility for better cohesion of subroutines and a bit of
  OOP as well. What this means is that I can drop most of my global variables
  and stick to loosely coupled functions.
