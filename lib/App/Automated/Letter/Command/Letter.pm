package App::Automated::Letter::Command::Letter;

use warnings;
use strict;

use vars qw(@ISA $VERSION);

=head1 NAME

App::Automated::Letter::Command::Letter - Plugin to create a serial letter

=head1 SYNOPSIS

=cut

our $VERSION = '0.001';

use App::Automated::Letter -command;

use Carp qw(croak);
use Params::Util qw(_HASH);
use DBI ();
use File::ConfigDir qw(0.003 config_dirs);
use File::Find::Rule ();
use File::Path       ();
use File::ShareDir   ();
use File::Spec       ();
use IPC::Cmd         ();
use Config::Any      ();
use Template         ();
use LaTeX::Encode    qw(latex_encode);

=head2 opt_spec

Delivers the options supported by this command class.

=cut

sub opt_spec
{
    return (
             [ "template|t=s",        "specifies the letter template to use" ],
             [ "body|b=s",            "specifies the serial letter body to use" ],
             [ "mode|m=s",            "specifies the letter mode to use (draft or final)" ],
             [ "format|f=s",          "specifies the output format ('tex', 'pdf', 'ps')" ],
             [ "address-table|a=s",   "specifies the address table to use" ],
             [ "config-file|c=s",     "specifies an alternate config file to use" ],
             [ "output-location|o=s", "specifies the output location (must exists)" ],
             [ "output-pattern|p=s",  "specifies the output name pattern (can contain '%d')" ],
           );
}

my %replvars = (
                 SHARE  => File::ShareDir::dist_dir("App-Automated-Letter"),
                 TMPDIR => File::Spec->tmpdir(),
		 PERL   => $^X,
                 %ENV,
               );

=head2 validate_args

Validates the arguments given by user.

=cut

sub validate_args
{
    my ( $self, $opt, $args ) = @_;
    my $config_file = 'serial';

    defined $opt->{'config_file'}
      and $config_file = $opt->{'config_file'};

    $self->{cfg} = _loadconfig($config_file);

    $self->{sql} = $self->{cfg}->{sql};

    defined $opt->{'address_table'}
      and $self->{sql}->{'address-table'} = $opt->{'address_table'};

    $self->{sql}->{'address-stmt'} ||= "SELECT * FROM %s";

    defined( $self->{sql}->{'address-table'} )
      or ( defined $self->{sql}->{'address-stmt'}
           and -1 == index( $self->{sql}->{'address-stmt'}, '%s' ) )
      or $self->usage_error("No address table or complete query given");

    $self->{sql}->{'address-stmt'} =
      sprintf( $self->{sql}->{'address-stmt'}, $self->{sql}->{'address-table'} );

    $self->{letteropt} = $self->{cfg}->{letter};
    defined( $self->{letteropt}->{mode} )
      and $self->{letteropt}->{mode} !~ m/^(?:draft|final)$/
      and $self->usage_error(   "Unsupported mode '"
                              . $self->{letteropt}->{mode}
                              . "' for letter in config file: use one of: 'draft', 'final'" );

    defined( $self->{cfg}->{print}->{mode} )
      and $self->{cfg}->{print}->{mode} !~ m/^(?:draft|final)$/
      and $self->usage_error(   "Unsupported mode '"
                              . $self->{cfg}->{print}->{mode}
                              . "' for print in config file: use one of: 'draft', 'final'" );

    defined( $opt->{body} )     and $self->{letteropt}->{body}     = $opt->{body};
    defined( $opt->{template} ) and $self->{letteropt}->{template} = $opt->{template};
    defined( $opt->{format} )   and $self->{letteropt}->{format}   = $opt->{format};
    defined( $opt->{mode} )     and $self->{letteropt}->{mode}     = $opt->{mode};

    defined( $self->{letteropt}->{template} )
      or $self->usage_error("No template specified");

    defined( $self->{letteropt}->{template} )
      and !-r $self->{letteropt}->{template}
      and $self->usage_error( $self->{letteropt}->{template} . ": " . $! );

    defined( $self->{letteropt}->{body} )
      or $self->usage_error("No letter body specified");

    defined( $self->{letteropt}->{body} )
      and !-r $self->{letteropt}->{body}
      and $self->usage_error( $self->{letteropt}->{body} . ": " . $! );

    defined( $self->{cfg}->{print}->{format} )
      or $self->{cfg}->{print}->{format} = 'ps';
    defined( $self->{cfg}->{print}->{format} )
      and $self->{cfg}->{print}->{format} !~ m/^(?:tex|ps|pdf)$/
      and $self->usage_error(   "Unsupported print format: '"
                              . $self->{cfg}->{print}->{format}
                              . "' - use one of 'tex', 'pdf', 'ps'" );

    defined( $self->{letteropt}->{format} )
      or $self->{letteropt}->{format} = 'pdf';
    defined( $self->{letteropt}->{format} )
      and $self->{letteropt}->{format} !~ m/^(?:tex|ps|pdf)$/
      and $self->usage_error(   "Unsupported letter format: '"
                              . $self->{letteropt}->{format}
                              . "' - use one of 'tex', 'pdf', 'ps'" );

    defined( $self->{letteropt}->{mode} )
      and $self->{letteropt}->{mode} !~ m/^(?:draft|final|print)$/
      and $self->usage_error(   "Unsupported mode: '"
                              . $self->{letteropt}->{mode}
                              . "' - use one of: 'draft', 'final', 'print'" );

    $self->{output} = $self->{cfg}->{output};
    defined( $opt->{'output_pattern'} )
      and $self->{output}->{pattern} = $opt->{'output_pattern'};

    defined $self->{output}->{pattern}
      or $self->{output}->{pattern} = "%s-%d";

    $self->{output}->{pattern} .= ".%s";

    defined( $opt->{output_location} )
      and $self->{output}->{location} = $opt->{output_location};

    defined( $self->{output}->{location} )
      or $self->usage_error("No output location specified");

    defined( $self->{output}->{location} )
      and !-d $self->{output}->{location}    # FIXME -w, -x
      and File::Path::make_path(
                                 $self->{output}->{location},
                                 {
                                    verbose => 0,
                                    mode    => 0755,
                                 }
                               );

    defined( $self->{output}->{location} )
      and !-w $self->{output}->{location}    # FIXME -w, -x
      and $self->usage_error( $self->{output}->{location} . ": " . $! );

    if ( $self->{letteropt}->{mode} eq 'print' )
    {
        defined( $self->{cfg}->{print}->{location} )
          or $self->{cfg}->{print}->{location} = $replvars{TMPDIR};

        defined( $self->{cfg}->{print}->{cmd} )
          or $self->usage_error("No print command specified");
    }

    defined( $self->{cfg}->{print}->{location} )
      and !-d $self->{cfg}->{print}->{location}    # FIXME -w, -x
      and File::Path::make_path(
                                 $self->{cfg}->{print}->{location},
                                 {
                                    verbose => 0,
                                    mode    => 0755,
                                 }
                               );

    defined( $self->{cfg}->{print}->{location} )
      and !-w $self->{cfg}->{print}->{location}    # FIXME -w, -x
      and $self->usage_error( $self->{cfg}->{print}->{location} . ": " . $! );

    if ( defined( $self->{cfg}->{print}->{cmd} ) )
    {
        $self->{cfg}->{print}->{cmd} = IPC::Cmd::can_run( $self->{cfg}->{print}->{cmd} )
          or $self->usage_error( "Can't get executable for '" . $self->{cfg}->{print}->{cmd} . "'" );
    }

    return;
}

=head2 command_names

Delivers the commands supported by this command class.

=cut

sub command_names
{
    return qw(serial);
}

sub _expandvalue;

sub _expandconfig
{
    my $cfg = $_[0];

    while ( my ( $k, $v ) = each( %{$cfg} ) )
    {
        defined($v) and $cfg->{$k} = _expandvalue($v);
    }

    return $cfg;
}

sub _expandvalue
{
    my $v = $_[0];

    defined($v) or return;

    my $t = ref($v);    # don't care if something in cfg is blessed
    if ( !$t )
    {
        while ( $v =~ m/(\${[^}]+})/g )    # XXX fix /* { */ ${la"}"}
        {
            my $p = $1;
            my $ek = substr( $p, 2, length($p) - 3 );
            if ( exists( $replvars{$ek} ) )
            {
                my $ev = defined( $replvars{$ek} ) ? $replvars{$ek} : "";
                substr( $v, pos($v) - length($p), length($p), $ev );
                pos($v) += length($ev) - length($p);
            }
        }
    }
    elsif ( "HASH" eq $t )
    {
        $v = _expandconfig($v);
    }
    elsif ( "ARRAY" eq $t )
    {
        my $i;
        for ( $i = 0; $i < scalar(@$v); ++$i )
        {
            defined( $v->[$i] ) and $v->[$i] = _expandvalue( $v->[$i] );
        }
    }
    elsif ( "SCALAR" eq $t )
    {
        defined($$v) and $$v = _expandvalue($$v);
    }

    return $v;
}

sub _loadconfig
{
    my $cfg;
    my $cfgpattern = "serial";
    my ( @cfgfiles, @cfgext, @cfgdirs, $cfgdir );

    defined( $_[0] )
      and ( $cfgpattern, $cfgdir ) = File::Basename::fileparse( $_[0] );

    if ( $cfgpattern !~ m/(?:\.[^\.]*)$/ )
    {
        my $exts = join( '|', Config::Any->extensions() );
        push( @cfgext, qr/$cfgpattern\.(?:$exts)$/ );
    }
    else
    {
        push( @cfgext, qr/$cfgpattern$/ );
    }

    if ( File::Spec->file_name_is_absolute($cfgdir) )
    {
        @cfgdirs = ($cfgdir);
    }
    else
    {
        my $cfgapp = $ENV{APP_AUTOLTTR_CONFIGBASE};
        defined($cfgapp)
          or $cfgapp = 'autolttr';
        @cfgdirs = config_dirs($cfgapp);
    }

    # scan config directories
    @cfgfiles = File::Find::Rule->file()->name(@cfgext)->maxdepth(1)->in(@cfgdirs);
    # @cfgfiles = grep { ( $_ =~ m/serial(?:\.[^\.]*)?$/ ) && ( -r $_ ) } @cfgfiles;

    if (@cfgfiles)
    {
	defined( $replvars{CFGDIR} )
	  or $replvars{CFGDIR} = File::Basename::dirname($cfgfiles[0]);
        my $cfghash = Config::Any->load_files(
                                               {
                                                 files           => [ $cfgfiles[0] ],
                                                 use_ext         => 1,
                                                 flatten_to_hash => 1,
                                               }
                                             );
        $cfg = $cfghash->{ $cfgfiles[0] };
    }
    else
    {
        croak("Missing configuration");
    }

    defined( _HASH($cfg) ) or croak("Invalid configuration");

    $cfg = _expandconfig($cfg);

    return $cfg;
}

=head2 execute

executes command

=cut

sub execute
{
    my ( $self, $opt, $args ) = @_;

    my $dbh = DBI->connect( @{ $self->{cfg}->{dbiconn} } )    or croak $DBI::errstr;
    my $sth = $dbh->prepare( $self->{sql}->{'address-stmt'} ) or croak $dbh->errstr;
    $sth->execute() or croak $dbh->errstr();
    my @addresses = $sth->fetchall_arrayref( {} );
    my @addrlist;
    foreach my $addritem ( @{ $addresses[0] } )
    {
	my %addr4latex = map { $_ => latex_encode( $addritem->{$_} ) } keys %$addritem;
	push( @addrlist, \%addr4latex );
    }

    my $template = Template->new(
                                  {
                                    ABSOLUTE => 1,
                                    RELATIVE => 1,
                                  }
                                );
    my $id = 0;
    my $ttcpath = File::Spec->catfile( $replvars{SHARE}, "tpl.tt2" );

    my @output_opt;
    $self->{output}->{pattern} =~ m/%s.*%d/
      and @output_opt =
      ( File::Basename::fileparse( $self->{letteropt}->{body}, qr/\.[^.]*$/ ) )[0];
    my @mode = ( $self->{letteropt}->{mode} );
    defined $self->{cfg}->{letter}->{mode}
      and push( @mode, $self->{cfg}->{letter}->{mode} );

    foreach my $address ( @addrlist )
    {
        foreach my $mode (@mode)
        {
            my %letteropt = %{ $self->{letteropt} };
            my $outputloc;
            if ( $mode eq 'print' )
            {
                defined( $self->{cfg}->{print}->{format} )
                  and $letteropt{format} = $self->{cfg}->{print}->{format};
                defined( $self->{cfg}->{print}->{location} )
                  and $outputloc = $self->{cfg}->{print}->{location};
                $letteropt{mode} = 'final';
                defined $self->{cfg}->{letter}->{mode}
                  and $letteropt{mode} = $self->{cfg}->{letter}->{mode};
            }
            else
            {
                defined( $self->{output}->{location} )
                  and $outputloc = $self->{output}->{location};
                defined $letteropt{mode}
                  and $letteropt{mode} = 'draft';
            }

            my @output_params = ( @output_opt, $id, $letteropt{format} );
            my $outname = sprintf( $self->{output}->{pattern}, @output_params );
            defined($outputloc)
              and $outname = File::Spec->catfile( $outputloc, $outname );
            my $rc = $template->process(
                                         $ttcpath,
                                         {
                                            address => $address,
                                            letter  => \%letteropt,
                                         },
                                         $outname,
                                       );
            $rc or croak( $template->error() );

            if ( $mode eq 'print' )
            {
                my @result;
                @result = IPC::Cmd::run(
					  command => [
							  $self->{cfg}->{print}->{cmd},
							  @{ $self->{cfg}->{print}->{args} },
							  $outname
						     ],
					  verbose => 0,
                );

                $result[0] or croak( $result[1] );
            }
        }
        ++$id;
        $self->{letteropt}->{mode} eq "draft" and last;
    }

    return 0;
}

1;
