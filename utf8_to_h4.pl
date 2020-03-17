#!/usr/bin/perl
#
# small UTF-8 helper in perl for sending init_script
# json sent in double quote

use utf8;                             # The source is encoded using UTF-8.
use open ':std', ':encoding(UTF-8)';  # The terminal provides/expects UTF-8.

while(<>) {
  chomp;
  # convert backslash
  s/\\/\\\\/g;

  # accent
  s/é/\\u00e9/g;
  s/è/\\u00e8/g;
  s/€/\\u20ac/g;
  s/î/\\u00ee/g;
  s/ç/\\u00e7/g;

  # escape double-quote for JSON
  s/"/\\"/g;
  # convert new-line to \n
  s/$/\\n/;

  print;
}
