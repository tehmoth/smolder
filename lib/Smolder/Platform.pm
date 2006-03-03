package Smolder::Platform;
use strict;
use warnings;

use File::Spec::Functions qw(catdir catfile canonpath);
use Cwd qw(cwd);
use Config;

=head1 NAME

Smolder::Platform - base class for platform build modules

=head1 SYNOPSIS

  package Redhat9::Platform;
  use base 'Smolder::Platform';

=head1 DESCRIPTION

This module serves as a base class for the platform build modules
which build help Smolder binary distributions.  See
F<docs/build_tech_spec.pod> for details about how the build system
works.

=head1 METHODS

This module is meant to be used as a base class, so the interface
consists of methods which may be overridden.  All these methods have a
reasonable default behavior.

All methods are called as class methods.  Platform modules are free to
use package variables to hold information between calls.

=head2 verify_dependencies

Makes sure all required dependencies are in place before starting the
build, and before beginning installation.  The C<mode> parameter will
be either "build" or "install" depending on when the method is called.

This method should either succeed or die() with a message for the
user.

By default, shared object (.so) files are searched for in $Config{libpth}.
header files (.h) are search for in $Config{usrinc}, /include and /usr/local/include

The default implementation runs the following default checks (which
are all overrideable):

    verify_dependencies(mode => 'install')

=cut

sub verify_dependencies {

    my ( $pkg, %arg ) = @_;
    my $mode = $arg{mode};
    my @PATH = split( ':', ( $ENV{PATH} || "" ) );

    # check perl
    if ( $mode eq 'install' ) {
        $pkg->check_perl();
    }

    # check mysql
    $pkg->check_mysql();
}

=head2 check_perl


Perl is the right version and compiled for the right architecture
(skipped in build mode).

=cut

sub check_perl {

    my $pkg = shift;

    # check that Perl is right for this build
    my %params = $pkg->build_params();

    my $perl = join( '.', ( map { ord($_) } split( "", $^V, 3 ) ) );
    if ( $perl ne $params{Perl} ) {
        die <<END;

This distribution of Smolder is compiled for Perl version
'$params{Perl}', but you have '$perl' installed.  You must either
install the expected version of Perl, or download a different release
of Smolder.  Please see the installation instructions in INSTALL for
more details.

END
    }

    if ( $Config{archname} ne $params{Arch} ) {
        die <<END;

This distribution of Smolder is compiled for the '$params{Arch}'
architecture, but your copy of Perl is compiled for
'$Config{archname}'.  You must download a different Smolder
distribution, or rebuild your Perl installation.  Please see the
installation instructions in INSTALL for more details.

END
    }
}

=head2 check_mysql

The C<mysql> shell is available and MySQL is v4.0.13 or higher.

=cut

sub check_mysql {
    my ( $pkg, %arg ) = @_;
    my @PATH = split( ':', ( $ENV{PATH} || "" ) );

    # look for MySQL command shell
    die <<END unless grep { -e catfile( $_, 'mysql' ) } @PATH;

MySQL not found. Smolder requires MySQL v4.0.13 or later.  If MySQL is 
installed, ensure that the 'mysql' client is in your PATH and try again.

END

    # check the version of MySQL
    no warnings qw(exec);
    my $mysql_version = `mysql -V 2>&1`;
    die "\n\nUnable to determine MySQL version using 'mysql -V'.\n" . "Error was '$!'.\n\n"
      unless defined $mysql_version
      and length $mysql_version;
    chomp $mysql_version;
    my ($version) = $mysql_version =~ /\s4\.(\d+\.\d+)/;
    die "\n\nMySQL version 4 not found.  'mysql -V' returned:" . "\n\n\t$mysql_version\n\n"
      unless defined $version;
    die "\n\nMySQL version too old. Smolder requires v4.0.13 or higher.\n"
      . "'mysql -V' returned:\n\n\t$mysql_version\n\n"
      unless $version >= 0.13;
}

=back

=item C<< $bin = find_bin(bin => $bin_name) >>

If $ENV{PATH} exists, searches $ENV{PATH} for $bin_name, returning the
full path to the desired executable.

If $ENV{PATH} does not contain /sbin or /usr/sbin, it will search those as well.

will die() with error if it cannot find the desired executable.

=cut

sub find_bin {

    my ( $pkg, %args ) = @_;

    my $bin = $args{bin};
    my $dir;

    my %additional_paths = (
        catdir( '/', 'sbin' ) => 1,
        catdir( '/', 'usr', 'sbin' ) => 1
    );

    my @PATH = split( ':', ( $ENV{PATH} || "" ) );

    foreach $dir (@PATH) {
        delete( $additional_paths{$dir} ) if ( $additional_paths{$dir} );
    }

    push @PATH, keys(%additional_paths);

    foreach $dir (@PATH) {

        my $exec = catfile( $dir, $bin );

        return $exec if ( -e $exec );
    }

    my $path = join ':', @PATH;

    die "Cannot find required utility '$bin' in PATH=$path\n\n";

}

=item C<< check_ip(ip => $ip) >>

Called by the installation system to check whether an IP address is
correct for the machine.  The default implementation runs
/sbin/ifconfig and tries to parse the resulting text for IP addresses.
Should return 1 if the IP address is ok, 0 otherwise.

=cut

sub check_ip {
    my ( $pkg, %arg ) = @_;
    my $IPAddress = $arg{ip};

    my $ifconfig = `/sbin/ifconfig`;
    my @ip_addrs = ();
    foreach my $if_line ( split( /\n/, $ifconfig ) ) {
        next unless ( $if_line =~ /inet\ addr\:(\d+\.\d+\.\d+\.\d+)/ );
        my $ip = $1;
        push( @ip_addrs, $ip );
    }
    unless ( grep { $_ eq $IPAddress } @ip_addrs ) {
        return 0;
    }
    return 1;
}

=item C<< $gid = create_group(options => \%options) >>

Called to create a Smolder Group, as specified by the command-line
argument to bin/smolder_install (--Group).  Takes the %options hash
built by smolder_install as the one argument.

The default version of this sub works for GNU/Linux.  Other platforms
(e.g. BSD-like) will need to override this method to work with their
platforms' requirements for user creation.

The sub will check to see if --Group exists, and create it if it
does not.  It will return the group ID (gid) in either case.

This sub will die with an error if it cannot create --Group.

=cut

sub create_group {
    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    my $groupadd_bin = $pkg->find_bin( bin => 'groupadd' );

    my $group = $options{Group};

    print "Creating UNIX group ('$group')\n";
    my ( $gname, $gpasswd, $gid, $gmembers ) = getgrnam($group);

    unless ( defined($gid) ) {
        my $groupadd = $groupadd_bin;
        $groupadd .= " $group";
        system($groupadd) && die("Can't add group: $!");

        ( $gname, $gpasswd, $gid, $gmembers ) = getgrnam($group);
        print "  Group created (gid $gid).\n";

    } else {
        print "  Group already exists (gid $gid).\n";
    }

    return $gid;
}

=item C<< $uid = create_user(group_id => $gid, options => \%options) >>

Called to create a Smolder User, as specified by the command-line
argument to bin/smolder_install (--User).  Takes the %options hash
built by smolder_install as the one argument.

The default version of this sub works for GNU/Linux.  Other platforms
(e.g. BSD-like) will need to override this method to work with their
platforms' requirements for user creation.

The sub will check to see if --User exists, and create it if it
does not.  If the user is created, the default group will be
--Group.  If the user already exists, it will be made a member of
the --Group group.

The sub will return the user ID (uid) if successful.

This sub will die with an error if it cannot create --User.

=cut

sub create_user {

    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    my $useradd_bin = $pkg->find_bin( bin => 'useradd' );

    my $user        = $options{User};
    my $group       = $options{Group};
    my $InstallPath = $options{InstallPath};

    # Get group info.
    my ( $gname, $gpasswd, $gid, $gmembers ) = getgrnam($group);

    # Create user, if necessary
    print "Creating UNIX user ('$user')\n";
    my ( $uname, $upasswd, $uid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire ) =
      getpwnam($user);

    unless ( defined($uid) ) {
        my $useradd = $useradd_bin;

        $useradd .= " -d $InstallPath -M $user -g $gid";
        system($useradd) && die("Can't add user: $!");

        # Update user data
        ( $uname, $upasswd, $uid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire ) =
          getpwnam($user);
        print "  User created (uid $uid).\n";
    } else {
        print "  User already exists (uid $uid).\n";
    }

    # Sanity check - make sure the user is a member of the group.
    ( $gname, $gpasswd, $gid, $gmembers ) = getgrnam($group);

    my @group_members = ( split( /\s+/, $gmembers ) );
    my $user_is_group_member = ( grep { $_ eq $user } @group_members );

    unless ( ( $ugid eq $gid ) or $user_is_group_member ) {
        $pkg->smolder_usermod( options => \%options );
    }

    return $uid;

}

=item C<< usermod(options => \%options) >>

Called when --User is not a member of --Group.  This sub
adds --User to --Group.

The default version of this sub works for GNU/Linux.  Other platforms
(e.g. BSD-like) will need to override this method to work with their
platforms' requirements for user creation.

This sub will die with an error if it cannot make --User a member
of --Group.

=cut

sub smolder_usermod {
    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    my $user  = $options{User};
    my $group = $options{Group};

    print "  Adding user $user to group $group.\n";

    my $usermod = $pkg->find_bin( bin => 'usermod' );

    $usermod .= " -G $group $user";

    system($usermod) && die("Can't add user $user to group $group: $!");
    print "  User added to group.\n";
}

=item C<< build_perl_module(name => $name) >>

Called to build a specific Perl module distribution called C<$name> in
the current directory.  The result of calling this method should be
one or more compiled Perl modules in Smolder's C<lib/> directory.

The default implementation includes code to answer questions asked by
some of the modules (using Expect) and special build procedures for
others.

The optional 'dest_dir' parameter specifies the location to put the
results of the build.  The default is SMOLDER_ROOT/lib.

=cut

sub build_perl_module {
    my ( $pkg, %arg ) = @_;
    my $name     = $arg{name};
    my $dest_dir = $arg{dest_dir} || catdir( $ENV{SMOLDER_ROOT}, 'lib' );

    # load expect unless we're building it
    my $use_expect = ( $name =~ /IO-Tty/ or $name =~ /Expect/ ) ? 0 : 1;
    _load_expect() if $use_expect;

    my $trash_dir = catdir( cwd, '..', 'trash' );

    print "\n\n************************************************\n\n", " Building $name",
      "\n\n************************************************\n\n";

    # Net::FTPServer needs this to not try to install /etc/ftp.conf
    local $ENV{NOCONF} = 1 if $name =~ /Net-FTPServer/;

    # Module::Build or MakeMaker?
    my ( $cmd, $make_cmd );
    if ( -e 'Build.PL' ) {
        $cmd =
            "$^X Build.PL "
          . " --install_path lib=$dest_dir"
          . " --install_path libdoc=$trash_dir"
          . " --install_path script=$trash_dir"
          . " --install_path bin=$trash_dir"
          . " --install_path bindoc=$trash_dir"
          . " --install_path arch=$dest_dir/$Config{archname}";

        $make_cmd = './Build';
    } else {
        $cmd =
          "$^X Makefile.PL LIB=$dest_dir PREFIX=$trash_dir INSTALLMAN3DIR=' ' INSTALLMAN1DIR=' '";
        $make_cmd = 'make';
    }

    # We only want the libs, not the executables or man pages
    if ($use_expect) {
        print "Running $cmd...\n";
        $pkg->expect_questions(
            cmd       => $cmd,
            questions => $pkg->perl_module_questions(),
        );

        print "Running $make_cmd...\n";
        $pkg->expect_questions(
            cmd       => $make_cmd,
            questions => $pkg->perl_module_questions(),
        );

    } else {

        # do it without Expect for IO-Tty and Expect installation.
        # Fortunately they don't ask any questions.
        print "Running $cmd...\n";
        system($cmd) == 0
          or die "$cmd failed: $?";
    }

    system("$make_cmd install") == 0 or die "$make_cmd install failed: $?";
}

sub perl_module_questions {
    return {
        "ParserDetails.ini?"                                 => 'n',
        "remove gif support?"                                => 'n',
        "mech-dump utility?"                                 => 'n',
        "configuration (y|n) ?"                              => 'n',
        "unicode entities?"                                  => 'n',
        "Do you want to skip these tests?"                   => 'y',
        "('!' to skip)"                                      => '!',
        "Mail::Sender? (y/N)"                                => 'n',
        "It requires access to an existing test database."   => 'n',
        "Do you want to build the XS Stash module?"          => 'y',
        "Do you want to use the XS Stash for all Templates?" => 'y',
        "Do you want to enable the latex filter?"            => 'n',
        "Do you want to install these components?"           => 'n',
    };
}

sub expect_questions {
    my ( $pkg, %options ) = @_;
    my $command   = Expect->spawn( $options{cmd} );
    my @responses = values %{ $options{questions} };
    my @questions = keys %{ $options{questions} };

    while ( my $match = $command->expect( undef, @questions ) ) {
        $command->send( $responses[ $match - 1 ] . "\n" );
    }
    $command->soft_close();
    if ( $command->exitstatus() != 0 ) {
        die "$options{cmd} failed: $?";
    }
}

sub apache_modperl_questions {
    return {
        "Configure mod_perl with" => 'y',
        "Shall I build httpd"     => 'n',
    };
}

=item C<< build_apache_modperl(apache_dir => $dir, modperl_dir => $dir, mod_auth_tkt_dir => $dir, mod_ssl_dir => $dir) >>

Called to build Apache and mod_perl in their respective locations.
Uses C<apache_build_parameters()> and C<modperl_build_parameters()>
which may be easier to override.  The result should be a working
Apache installation in C<apache/>.

=cut

sub build_apache_modperl {
    my ( $pkg, %arg ) = @_;
    my ( $apache_dir, $mod_perl_dir, $mod_auth_tkt_dir, $mod_ssl_dir ) =
      @arg{qw(apache_dir mod_perl_dir mod_auth_tkt_dir mod_ssl_dir)};
    _load_expect();

    print "\n\n************************************************\n\n",
      "  Building Apache/mod_ssl/mod_perl/mod_auth_tkt",
      "\n\n************************************************\n\n";

    # gather params
    my $apache_params   = $pkg->apache_build_parameters(%arg);
    my $mod_perl_params = $pkg->mod_perl_build_parameters(%arg);
    my $mod_ssl_params  = $pkg->mod_ssl_build_parameters(%arg);
    my $old_dir         = cwd;

    print "\n\n************************************************\n\n", "  Building mod_ssl",
      "\n\n************************************************\n\n";

    # build mod_ssl
    chdir($mod_ssl_dir) or die "Unable to chdir($mod_ssl_dir): $!";
    my $cmd = "./configure --with-apache=../$apache_dir $mod_ssl_params";
    print "Calling '$cmd'\n";
    system($cmd ) == 0
      or die "Unable to configure mod_ssl: $!";
    chdir($old_dir);

    print "\n\n************************************************\n\n", "  Building mod_perl",
      "\n\n************************************************\n\n";

    # build mod_perl
    chdir($mod_perl_dir) or die "Unable to chdir($mod_perl_dir): $!";
    $cmd = "$^X Makefile.PL $mod_perl_params";
    print "Calling '$cmd'...\n";

    my $command = $pkg->expect_questions(
        cmd       => $cmd,
        questions => $pkg->apache_modperl_questions(),
    );

    system("make PERL=$^X") == 0
      or die "mod_perl make failed: $?";
    system("make install PERL=$^X") == 0
      or die "mod_perl make install failed: $?";

    print "\n\n************************************************\n\n", "  Building Apache",
      "\n\n************************************************\n\n";

    # build Apache
    chdir($old_dir)    or die $!;
    chdir($apache_dir) or die "Unable to chdir($apache_dir): $!";
    print "Calling './configure $apache_params'.\n";
    system("./configure $apache_params") == 0
      or die "Apache configure failed: $?";
    system("make") == 0
      or die "Apache make failed: $?";
    system("make install") == 0
      or die "Apache make install failed: $?";
    system("make certificate TYPE=DUMMY") == 0
      or die "Apache make failed: $?";

    # clean up unneeded apache directories
    my $root = $ENV{SMOLDER_ROOT};
    system("rm -rf $root/apache/man $root/apache/htdocs/*");

    print "\n\n************************************************\n\n", "  Building mod_auth_tkt",
      "\n\n************************************************\n\n";

    # build mod_auth_tkt
    chdir($old_dir)          or die $!;
    chdir($mod_auth_tkt_dir) or die "Unable to chdir($mod_auth_tkt_dir): $!";
    $cmd = "./configure --apxs=$root/apache/bin/apxs --debug --debug-verbose";
    print "Calling '$cmd'.\n";
    system($cmd) == 0
      or die "mod_auth_tkt build failed: $?";
    $cmd = "make && make install";
    print "Calling '$cmd'.\n";
    system($cmd) == 0
      or die "mod_auth_tkt installation failed: $?";
}

=item C<< apache_build_parameters(apache_dir => $dir, modperl_dir => $dir) >>

Returns a string containing the parameters passed to Apache's
C<configure> script by C<build_apache_modperl()>.

=cut

sub apache_build_parameters {
    my $root = $ENV{SMOLDER_ROOT};
    return "--prefix=${root}/apache "
      . "--activate-module=src/modules/perl/libperl.a "
      . "--disable-shared=perl "
      . "--enable-module=ssl          --enable-shared=ssl "
      . "--enable-module=rewrite      --enable-shared=rewrite "
      . "--enable-module=proxy        --enable-shared=proxy "
      . "--enable-module=mime_magic   --enable-shared=mime_magic "
      . "--enable-module=unique_id    --enable-shared=unique_id "
      . "--without-execstrip "
      . "--enable-module=so";
}

=item C<mod_perl_build_parameters(apache_dir => $dir, modperl_dir => $dir)>

Returns a string containing the parameters passed to mod_perl's
C<Makefile.PL> script by C<build_apache_modperl()>.

=cut

sub mod_perl_build_parameters {
    my ( $pkg, %arg ) = @_;
    my $root  = $ENV{SMOLDER_ROOT};
    my $trash = catdir( cwd, '..', 'trash' );

    return "LIB=$root/lib "
      . "PREFIX=$trash "
      . "APACHE_SRC=$arg{apache_dir}/src "
      . "USE_APACI=1 "
      . "PERL_DEBUG=1 APACI_ARGS='--without-execstrip' EVERYTHING=1";
}

=item C<mod_ssl_build_parameters(apache_dir => $dir)>

Returns a string containing the parameters passed to configure.

=cut

sub mod_ssl_build_parameters {
    my ( $pkg, %arg ) = @_;
    return "--enable-shared=ssl --apache=../$arg{apache_dir}";
}

sub build_swishe {
    my ( $pkg, %options ) = @_;
    my $dir = $options{swishe_dir};

    system( "./configure --prefix=$dir/swish-e " . "--exec_prefix=$dir/swish-e" ) == 0
      or die "Unable to configure swish-e! $!";
    system("make && make install") == 0
      or die "Unable to make swish-e! $!";
}

=item C<finish_installation(options => \%options)>

Anything that needs to be done at the end of installation can be done
here.  The default implementation does nothing.  The options hash
contains all the options passed to C<smolder_install> (ex: InstallPath).

=cut

sub finish_installation { }

=item C<finish_upgrade()>

Anything that needs to be done at the end of an upgrade can be done
here.  The default implementation does nothing.

=cut

sub finish_upgrade { }

=item C<< post_install_message(options => \%options) >>

Called by bin/smolder_install, returns install information once everything
is complete.

=cut

sub post_install_message {

    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    print <<EOREPORT;


#####                                                         #####
###                                                             ###
                   Smolder INSTALLATION COMPLETE               
###                                                             ###
#####                                                         #####


   Installed at   : $options{InstallPath}
   Control script : $options{InstallPath}/bin/smolder_ctl
   Config file    : $options{InstallPath}/conf/smolder.conf
   Admin Password : 'qa_rocks'
  

   Running on $options{IPAddress} - http://$options{HostName}:$options{ApachePort}/

EOREPORT

}

=item C<post_upgrade_message(options => \%options)>

Called by bin/smolder_upgrade, returns upgrade information once everything
is complete.

=cut

sub post_upgrade_message {

    my ( $pkg, %args ) = @_;

    my %options = %{ $args{options} };

    print <<EOREPORT;


#####                                                         #####
###                                                             ###
                  Smolder UPGRADE COMPLETE                       
###                                                             ###
#####                                                         #####


   Installed at:      $options{InstallPath}
   Control script:    $options{InstallPath}/bin/smolder_ctl
   Smolder conf file: $options{InstallPath}/conf/smolder.conf

   Running on $options{IPAddress} --
     http://$options{HostName}:$options{ApachePort}/
     ftp://$options{HostName}:$options{FTPPort}/

EOREPORT

}

=item C<guess_platform()>

Called to guess whether this module should handle building on this
platform.  This is used by C<smolder_build> when the user doesn't
specify a platform.  This method should return true if the module
wants to handle the platform.

The default implementation returns false all the time.  When
implementing this module, err on the side of caution since the user
can always specify their platform explicitely.

=cut

sub guess_platform {
    return 0;
}

=item C<build_params()>

Reads the F<data/build.db> file produced by C<smolder_build> and returns
a hash of the values available (Platform, Perl, Arch).

=cut

sub build_params {
    my $db_file = catfile( $ENV{SMOLDER_ROOT}, 'data', 'build.db' );
    return () unless -e $db_file;

    # it would be nice to use Config::ApacheFormat here, but
    # unfortunately it's not possible to guarantee that it will load
    # because it uses Scalar::Util which is an XS module.  If the
    # caller isn't running the right architecture then it will fail to
    # load.  So, fall back to parsing by hand...
    open( DB, $db_file ) or die "Unable to open '$db_file': $!\n";
    my ( $platform, $perl, $arch );
    while (<DB>) {
        chomp;
        next if /^\s*#/;
        if (/^\s*platform\s+["']?([^'"]+)["']?/i) {
            $platform = $1;
        } elsif (/^\s*perl\s+["']?([^'"]+)/i) {
            $perl = $1;
        } elsif (/^\s*arch\s+["']?([^'"]+)/i) {
            $arch = $1;
        }
    }
    close DB;

    return (
        Platform => $platform,
        Perl     => $perl,
        Arch     => $arch
    );
}

=back

=cut

#
# internal method to actually search for libraries.
# takes 'so' and 'h' args for the files to look for.
# takes 'includes' and 'lib_files' as the directories to search for.
#

sub _check_libs {

    my ( $pkg, %args ) = @_;
    my $mode = $args{mode};

    my $name = $args{name};
    my $so   = $args{so};
    my $h    = $args{h};

    my $re = qr/^$so/;

    die "\n\n$name is missing from your system.\n" . "This library is required by Smolder.\n\n"
      unless grep { /^$re/ } @{ $args{lib_files} };
    die <<END unless $mode eq 'install' or grep { -e catfile( $_, $h ) } @{ $args{includes} };

The header file for $name, '$h', is missing from your system.
This file is needed to compile the Imager module which uses $name.

END

}

sub _load_expect {

    # load Expect - don't load at compile time because this module is
    # used during install when Expect isn't needed
    eval "use Expect;";
    die <<END if $@;

Unable to load the Expect Perl module.  You must install Expect before
running smolder_build.  The source packages you need are included with
Project:

   src/IO-Tty-1.02.tar.gz
   src/Expect-1.15.tar.gz

END
}

1;
