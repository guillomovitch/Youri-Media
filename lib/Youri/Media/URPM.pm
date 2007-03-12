# $Id$
package Youri::Media::URPM;

=head1 NAME

Youri::Media::URPM - URPM-based media implementation

=head1 DESCRIPTION

This is an URPM-based L<Youri::Media> implementation.

It can be created either from local or remote full (hdlist) or partial
(synthesis) compressed header files, or from a package directory. File-based
inputs are only usable with this latest option.

=cut

use strict;
use warnings;
use Carp;
use File::Find;
use File::Temp ();
use LWP::Simple;
use URPM;
use Youri::Package::RPM::URPM;

use base 'Youri::Media';

=head1 CLASS METHODS

=head2 new(%args)

Creates and returns a new Youri::Media::URPM object.

Specific parameters:

=over

=item synthesis $synthesis

Path, URL or list of path or URL of synthesis file used for creating
this media. If a list is given, the first successfully accessed will be used,
so as to allow better reliability.

=item hdlist $hdlist

Path, URL or list of path or URL of hdlist file used for creating
this media. If a list is given, the first successfully accessed will be used,
so as to allow better reliability.

=item path $path

Path of package directory used for creating this media.

=item max_age $age

Maximum age of packages for this media.

=item rpmlint_config $file

rpmlint configuration file for this media.

=back

In case of multiple B<synthesis>, B<hdlist> and B<path> options given, they
will be tried in this order, so as to minimize parsing time.

=cut

sub _init {
    my $self   = shift;

    my %options = (
        hdlist         => '',    # hdlist from which to create this media
        synthesis      => '',    # synthesis from which to create this media
        path           => '',    # directory from which to create this media
        @_
    );

    # check options
    if ($options{path}) {
        if (! -d $options{path}) {
            carp "non-existing directory $options{path}, dropping";
        } elsif (! -r $options{path}) {
            carp "non-readable directory $options{path}, dropping";
        } else {
            $self->{_path} = $options{path};
        }
    }

    # find source
    SOURCE: {
        if ($options{synthesis}) {
            foreach my $file (
                ref $options{synthesis} eq 'ARRAY' ?
                    @{$options{synthesis}} :
                    $options{synthesis}
            ) {
                my $synthesis = $self->_get_file($file);
                if ($synthesis) {
                    $self->{_synthesis} = $synthesis;
                    last SOURCE;
                }
            }
        }

        if ($options{hdlist}) { 
            foreach my $file (
                ref $options{hdlist} eq 'ARRAY' ?
                    @{$options{hdlist}} :
                    $options{hdlist}
            ) {
                my $hdlist = $self->_get_file($file);
                if ($hdlist) {
                    $self->{_hdlist} = $hdlist;
                    last SOURCE;
                }
            }
        }

        if ($self->{_path}) {
            last SOURCE;
        }
        
        croak "no source specified";
    }

    return $self;
}

sub _remove_all_archs {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    $self->{_urpm}->{depslist} = [];
}

sub _remove_archs {
    my ($self, $skip_archs) = @_;
    croak "Not a class method" unless ref $self;

    my $urpm = $self->{_urpm};
    $urpm->{depslist} = [
         grep { ! $skip_archs->{$_->arch()} } @{$urpm->{depslist}}
    ];
}

sub get_package_class {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return "Youri::Package::RPM::URPM";
}

sub traverse_files {
    my ($self, $function) = @_;
    croak "Not a class method" unless ref $self;
    croak "No files for this media" unless $self->{_path};

    my $callback = sub {
        return unless -f $File::Find::name;
        return unless -r $File::Find::name;
        return unless $_ =~ /\.rpm$/;

        my $package = Youri::Package::RPM::URPM->new(file => $File::Find::name);
        return if $self->{_skip_archs}->{$package->get_arch()};

        $function->($File::Find::name, $package);
    };

    find($callback, $self->{_path});
}

sub traverse_headers {
    my ($self, $function) = @_;
    croak "Not a class method" unless ref $self;

    # lazy initialisation
    $self->_parse_headers() unless $self->{_urpm};

    $self->{_urpm}->traverse(sub {
        $function->(Youri::Package::RPM::URPM->new(header => $_[0]));
    });
    
}

sub _parse_headers {
    my ($self) = @_;

    $self->{_urpm} = URPM->new();
    CASE: {
        if ($self->{_synthesis}) {
            print "Parsing synthesis $self->{_synthesis}\n"
                if $self->{_verbose};
            $self->{_urpm}->parse_synthesis(
                $self->{_synthesis}, keep_all_tags => 1
            );
            last CASE;
        }

        if ($self->{_hdlist}) {
            print "Parsing synthesis $self->{_hdlist}\n"
                if $self->{_verbose};
            $self->{_urpm}->parse_hdlist(
                $self->{_hdlist}, keep_all_tags => 1
            );
            last CASE;
        }

        if ($self->{_path}) {
            print "Parsing directory $self->{_path} content\n"
                if $self->{_verbose};

            my $pattern = qr/\.rpm$/;

            my $parse = sub {
                return unless -f $File::Find::name;
                return unless -r $File::Find::name;
                return unless $_ =~ $pattern;

                $self->{_urpm}->parse_rpm(
                    $File::Find::name, keep_all_tags => 1
                );
            };

            find($parse, $self->{_path});
            last CASE;
        }
    }
}


=head1 INSTANCE METHODS

=head2 get_hdlist()

Returns hdlist used for creating this media, if any.

=cut

sub get_hdlist {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_hdlist};
}

=head2 get_path()

Returns path used for creating this media, if any.

=cut

sub get_path {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_path};
}

sub _get_file {
    my ($self, $file) = @_;

    if ($file =~ /^(?:http|ftp):\/\/.*$/) {
        print "Attempting to retrieve file $file\n" if $self->{_verbose};
        my $tempfile = File::Temp->new();
        my $status = getstore($file, $tempfile->filename());
        unless (is_success($status)) {
            carp "invalid URL $file: $status";
            return;
        }
        return $tempfile;
    } else {
        unless (-f $file) {
            carp "non-existing file $file";
            return;
        }
        unless (-r $file) {
            carp "non-readable file $file";
            return;
        }
        return $file;
    }
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002-2006, YOURI project

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
