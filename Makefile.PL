use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	         => 'Template::Plugin::DBI',
    'VERSION_FROM'   => 'DBI.pm',
    PREREQ_PM        => { Template => 1.00, DBI => 0 },
    'dist'           => {
		'COMPRESS' => 'gzip',
		'SUFFIX'   => 'gz',
    },
);


print <<EOF;

In order to run the test suite correctly you must set the following 
environment variables:
DBI_DSN  = datasource that describes your test database

e.g. dbi:mysql:test

DBI_USER = if a username is required for the above datasource
DBI_PASS = if a password is required for the above datasource

EOF
