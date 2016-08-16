Perl Alternative
----------------

I've decided to re-implement sshprint in Perl.

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

And now onto why Perl (and not Python, Ruby, or even C)? To be honest, I would
like to write this app in C --- actually I'd love to create a two-in-one sort of
app that could work directly with the `lpr' like `sshlpr2' attempts and also
work as standalone (for systems with no printer server setup). But I don't have
the time at the moment to really give my complete focus to that goal --- I can achieve
the same effect with Perl.
