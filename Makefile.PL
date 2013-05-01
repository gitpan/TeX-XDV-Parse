use ExtUtils::MakeMaker;

my $needs_to_build = {
    #__BUILD__
    'Test::More' => 0,
};

my $needs_to_run = {
    #__MODULES__
    'TeX::DVI::Parse' => 0,
};

WriteMakefile(
    NAME              => 'TeX::XDV::Parse',
    VERSION_FROM      => 'lib/TeX/XDV/Parse.pm', # finds $VERSION
    PREREQ_PM         => $needs_to_run,
    BUILD_REQUIRES    => $needs_to_build,
    LICENSE           => 'perl',
    ($] >= 5.005
        ? (
            ABSTRACT_FROM  => 'lib/TeX/XDV/Parse.pm',
            AUTHOR         => 'Rick Myers <jrm@cpan.org>'
        )
        : (
        )
    ),
    clean => {
        FILES => join ' ', qw{
            MANIFEST.bak
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

1;

