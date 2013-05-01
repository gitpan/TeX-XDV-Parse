package TeX::XDV::Parse;
use strict;
use warnings;

require TeX::DVI::Parse;

@TeX::XDV::Parse::ISA = 'TeX::DVI::Parse';

$TeX::XDV::Parse::VERSION = '0.01';

use constant {  # from xdvipdfmx
    XDV_FLAG_FONTTYPE_ATSUI => 0x0001,
    XDV_FLAG_FONTTYPE_ICU   => 0x0002,
    XDV_FLAG_VERTICAL       => 0x0100,
    XDV_FLAG_COLORED        => 0x0200,
    XDV_FLAG_FEATURES       => 0x0400,
    XDV_FLAG_VARIATIONS     => 0x0800,
    XDV_FLAG_EXTEND         => 0x1000,
    XDV_FLAG_SLANT          => 0x2000,
    XDV_FLAG_EMBOLDEN       => 0x4000,
};

# Hmm.. either way we do this, the dispatcher in DVI::Parse
# sees the same thing. Either way, it ends up calling either
# DVI's handler or the one here. Since we're not trying to
# override anything, it doesn't really matter. The end result
# is the same as seen from the superclassing module.

#our @COMMANDS;
#*COMMANDS = *TeX::DVI::Parse::COMMANDS;

push @TeX::DVI::Parse::COMMANDS, (
    # opcode 250 is still unused, as in TeX::DVI::Parse
    [ 'pic_file',        \&make_pic_file ],         # 251
    [ 'native_font_def', \&make_native_font_def ],  # 252
    [ 'glyph_array',     \&make_glyph_array ],      # 253
    [ 'glyph_string',    \&make_glyph_string ],     # 254
    [ 'dir',             \&dir ],                   # 255
    'undefined_command'                             # 256, not possible
);

sub make_glyph_thingy {
    my $is_array = shift;
    my $buff = pop @_;

    # width, count
    my @list =
        unpack "lna*",
        pack   "Lna*",
        unpack "Nna*",
        $buff;
    $buff = pop @list;

    # locations, glyphs
    my $c = $list[-1];
    my $z = $is_array ? $c<<1 : $c;
    push @list,
        unpack "l${z}n${c}a*",
        pack   "L${z}n${c}a*",
        unpack "N${z}n${c}a*",
        $buff;
    $buff = pop @list;

    return @_, @list, $buff;
}

sub make_glyph_string { make_glyph_thingy( 0, @_ ) }
sub make_glyph_array  { make_glyph_thingy( 1, @_ ) }

sub make_pic_file {
    my $buff = pop @_;
    my @list =
        unpack "CllllllsSa*",
        pack   "CLLLLLLSSa*",
        unpack "CNNNNNNnna*",
        $buff;
    $buff = pop @list;
    my $file;
    ($file,$buff) = unpack "A$list[-1]a*", $buff;
    return @_, @list, $file , $buff;
}

sub make_native_font_def {
    my $buff = pop @_;

    # font_id, point_size, flags
    my @list =
        unpack "lLna*",
        pack   "LLna*",
        unpack "NNna*",
        $buff;
    $buff = pop @list;

    my $f = $list[-1];

    die "invalid signature"
        unless $f & XDV_FLAG_FONTTYPE_ICU || $f & XDV_FLAG_FONTTYPE_ATSUI;

    # plen, flen, slen
    push @list, unpack "CCCa*", $buff;
    $buff = pop @list;

    # font_name, family_name, style_name
    push @list, unpack "A$list[-3]A$list[-2]A$list[-1]a*", $buff;
    $buff = pop @list;

    # rgba_color
    if ($f & XDV_FLAG_COLORED) {
        push @list, unpack "Na*", $buff;
        $buff = pop @list;
    }

    # variations
    if ($f & XDV_FLAG_VARIATIONS) {
        push @list, unpack "na*", $buff;
        $buff = pop @list;
        my $n = $list[-1];
        push @list,
            unpack "l${n}N${n}a*", # need to make sure first is signed
            pack   "L${n}N${n}a*",
            unpack "N${n}N${n}a*",
            $buff;
        $buff = pop @list;
    }

    # extend ?
    if ($f & XDV_FLAG_EXTEND) {
        push @list,
            unpack "la*",
            pack   "La*",
            unpack "Na*",
            $buff;
        $buff = pop @list;
    }

    # slant ?
    if ($f & XDV_FLAG_SLANT) {
        push @list,
            unpack "la*",
            pack   "La*",
            unpack "Na*",
            $buff;
        $buff = pop @list;
    }

    # bold ?
    if ($f & XDV_FLAG_EMBOLDEN) {
        push @list,
            unpack "la*",
            pack   "La*",
            unpack "Na*",
            $buff;
        $buff = pop @list;
    }

    return @_, @list, $buff;
}

sub dir {
    my $buff = pop @_;
    my @list = unpack "Ca*", $buff;
    $buff = pop @list;
    $list[-1] = $list[-1] ? 1 : 0;  # 0=horizontal 1=vertical
    return @_, @list, $buff;
}

sub undefined_command {
    die "undefined_command: @_\n";
}

1;

__END__

=head1 NAME

TeX::XDV::Parse - Perl extension for parsing TeX XDV files

=head1 SYNOPSIS

  package My_XDV_Parser;
  use TeX::XDV::Parse;
  @ISA = qw( TeX::XDV::Parse );

  sub dir {...}
  sub pic_file {...}
  sub glyph_array {...}
  sub glyph_string {...}
  sub native_font_def {...}

=head1 DESCRIPTION

TeX::XDV::Parse is an extension of TeX::DVI::Parse, much as XDV is
an extension of DVI. This module simply overlays the additional XDV
functionality on top of TeX::DVI::Parse and inherits its interface.

To use, you should subclass this module and define functions to handle
each of the XDV/DVI commands. Each command will be passed the appropriate
arguments. For example:

  sub dir {
    my ($self, $opcode, $direction) = @_;
    ...
  }

See the TeX::DVI::Parse documentation for details on the DVI commands.

=head1 METHODS

=head2 dir( direction )

Sets either left to right or top to bottom direction.

  0 = horizontal
  1 = vertical

=head2 pic_file( $type, $a, $b, $c, $d, $tx, $ty, $page, $len, $file )

Sets an image.

  type : file type
     a : affine transform element
     b : affine transform element
     c : affine transform element
     d : affine transform element
    tx : affine transform element
    ty : affine transform element
   len : length of filename
  page : page number
  file : filename

The affine transform takes the form

  [ a   b   0 ]
  [ c   d   0 ]
  [ tx  ty  1 ]

In general though, to transform a point (x,y):

  x' = ax + cy + tx
  y' = bx + dy + ty

=head2 glyph_string( $width, $count, $x_loc, ..., $glyph, ... )

Set a string of glyphs.

  width : TeX width
  count : glyph count
  x_loc : TeX horizontal location (x count)
  glyph : glyph id (x count)

The glyph string will generally be broken at word boundaries with
whitespace excluded. The exception is at line endings where a word is
hypenated. The word will naturally be broken into two seperate glyph
strings.

B<x_loc> and B<glyph> are repeated B<count> times.

B<glyph> is the glyph id of the character to set in the current font,
which isn't necessarily the same as the characters ordinal value.

=head2 glyph_array( $width, $count, $x_loc, $y_loc, ..., $glyph, ... )

Set an array of glyphs.

  width : TeX width
  count : glyph count
  x_loc : TeX horizontal location (x count)
  y_loc : TeX vertical location (x count)
  glyph : glyph id (x count)

A glyph array is similar to a glyph string, but also include vertical
location information.

B<x_loc> and B<y_loc> are sent in pairs. The pairs are repeated B<count>
times. B<glyph> is also repeated B<count> times, but after all the
B<x_loc> and B<y_loc> pairs.

B<glyph> is the glyph id of the character to set in the current font,
which isn't necessarily the same as the characters ordinal value.

=head2 native_font_def( $k, $ps, $fl, $p_len, $f_len, $s_len, $n, $f, $s, $c, $n, $v, $ext, $slt, $emb )

Defines a font.

      k : font id
     ps : point size in TeX units
     fl : flags
  p_len : ps name len
  f_len : family name len
  s_len : style name len
      n : font_name
      f : fam_name
      s : sty_name
      c : rgba_color
      n : nvars
      v : variations * nvars
    ext : extend
    slt : slant
    emb : embolden

Many of these are unknown. B<k>, B<ps>, and B<n> are the only ones seen
so far. See the source code for some flag constants and how the command is
decoded. Any information regarding this, or documentation patches welcome.

=head1 EXPORT

None.

=head1 SEE ALSO

TeX::DVI::Parse

=head1 AUTHOR

Rick Myers, E<lt>jrm at cpan dot orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Rick Myers

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.

=cut

