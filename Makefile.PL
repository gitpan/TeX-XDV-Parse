use 5.005;
use ExtUtils::MakeMaker;

my $needs_to_configure = {
    'ExtUtils::MakeMaker' => 0,
};

my $needs_to_build = {
    #__BUILD__
    'strict'     => 0,
    'warnings'   => 0,
    'Exporter'   => 0,
    'Test::More' => 0,
    'Text::Diff' => 0,
};

my $needs_to_run = {
    #__MODULES__
    'strict'          => 0,
    'warnings'        => 0,
    'constant'        => 0,
    'Exporter'        => 0,
    'TeX::DVI::Parse' => 0,
};

WriteMakefile(
    NAME               => 'TeX::XDV::Parse',
    VERSION_FROM       => 'lib/TeX/XDV/Parse.pm', # finds $VERSION
    PREREQ_PM          => $needs_to_run,
    BUILD_REQUIRES     => $needs_to_build,
    CONFIGURE_REQUIRES => $needs_to_configure,
    LICENSE            => 'perl',
    ABSTRACT_FROM      => 'lib/TeX/XDV/Parse.pm',
    AUTHOR             => 'Rick Myers <jrm@cpan.org>',
    clean => {
        FILES => join ' ', qw{
            MANIFEST.bak
            MANIFEST.SKIP.bak
            t/print.out
        },
    },
);

package MY;

# run bin/fixup_install at 'make manifest' time
sub dist_basics {
    my $o = shift->SUPER::dist_basics(@_);
    $o =~ s/(manifest :)/$1 fixup_install/m;
    $o .= "fixup_install :\n";
    $o .= "\tMODULE_VERSION='\$(VERSION)' ";
    $o .= "VERSION_FROM='\$(VERSION_FROM)' ";
    $o .= "MODULE_NAME='\$(NAME)' ";
    $o .= "bin/fixup_install\n";
    return $o;
}

sub postamble {
    my $o = shift->SUPER::postamble(@_);
    my $n = <<'EOP';
        t/print.xdv : t/print.tex
            cd t && $(RM_F) print.xdv
            cd t && xelatex -no-pdf print
            cd t && $(RM_F) print.aux print.log

        t/print.cmp : t/print.xdv
            $(ABSPERLRUNINST) -Iinc -MTeX::XDV::Print \
                -e'TeX::XDV::Print->new(q{t/print.xdv})->parse' \
                > t/print.cmp

        xdv : t/print.cmp
EOP
    $n =~ s/^ {8}//mg;
    $n =~ s!^ +! $len=length($&)>>2; "\t"x$len !emg;
    return $o . $n;
}

sub test_via_harness {
    my $o = shift->SUPER::test_via_harness(@_);
    $o =~ s!,!, 'inc',!;
    return $o;
}

1;

