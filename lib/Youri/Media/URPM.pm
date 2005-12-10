# $Id$
package Youri::Media::URPM;

=head1 NAME

Youri::Media::URPM - URPM-based Media class

=head1 DESCRIPTION

This is an URPM-based Media class implementation.

It can be created either from local or remote full (hdlist) or partial
(synthesis) compressed header files, or from a package directory. File-based
inputs are only usable with this latest option.

=cut

use URPM;
use File::Find;
use File::Temp ();
use Youri::Utils;
use LWP::Simple;
use Carp;
use strict;
use warnings;
use Youri::Package::URPM;

use base 'Youri::Media::Base';

=head1 CLASS METHODS

=head2 new(I<%hash>)

Returns a C<Youri::Media::URPM> object.

Specific parameters:

=over

=item B<hdlist>

URL of the hdlist file used for creating this media.

=item B<synthesis>

URL of the synthesis file used for creating this media.

=item B<path>

path of the package directory used for creating this media.

=item B<max_age>

maximum age of packages for this media.

=item B<rpmlint_config>

rpmlint configuration file for this media.

=back

=cut

sub _init {
    my $self   = shift;

    my %options = (
        hdlist         => '',    # hdlist from which to create this media
        synthesis      => '',    # synthesis from which to create this media
        path           => '',    # directory from which to create this media
        max_age        => '',    # maximum build age for packages
        rpmlint_config => '',    # rpmlint configuration for packages
        @_
    );

    my $urpm = URPM->new();
    SOURCE: {
        if ($options{synthesis}) {
            print "Attempting to retrieve synthesis from $options{synthesis}\n" if $options{verbose};
            my $synthesis = $self->_get_file($options{synthesis});
            if ($synthesis) {
                $urpm->parse_synthesis($synthesis, keep_all_tags => 1);
                last SOURCE;
            }
        }

        if ($options{hdlist}) { 
            print "Attempting to retrieve hdlist from $options{hdlist}\n" if $options{verbose};
            my $hdlist = $self->_get_file($options{hdlist});
            if ($hdlist) {
                $urpm->parse_hdlist($hdlist, keep_all_tags => 1);
                last SOURCE;
            }
        }

        if ($options{path}) {
            print "Attempting to scan directory $options{path}\n" if $options{verbose};
            unless (-d $options{path}) {
                carp "non-existing dir $options{path}";
                last SOURCE;
            }
            unless (-r $options{path}) {
                carp "non-readable dir $options{path}";
                last SOURCE;
            }

            my $parse = sub {
            return unless -f $File::Find::name;
            return unless -r $File::Find::name;
            return unless /\.rpm$/;

            $urpm->parse_rpm($File::Find::name, keep_all_tags => 1);
            };

            find($parse, $options{path});
            last SOURCE;
        }
        
        croak "no source specified";
    }

    $self->{_urpm}           = $urpm;
    $self->{_path}           = $options{path};
    $self->{_max_age}        = $options{max_age};
    $self->{_rpmlint_config} = $options{rpmlint_config};

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

=head1 INSTANCE METHODS

=head2 max_age()

Returns maximum age of packages for this media.

=cut

sub max_age {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_max_age};
}

=head2 rpmlint_config()

Returns rpmlint configuration file for this media.

=cut

sub rpmlint_config {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_rpmlint_config};
}

sub traverse_files {
    my ($self, $function) = @_;
    croak "Not a class method" unless ref $self;

    my $callback = sub {
        return unless -f $File::Find::name;
        return unless -r $File::Find::name;
        return unless $_ =~ /\.rpm$/;

        my $package = Youri::Package::URPM->new(file => $File::Find::name);
        return if $self->{_skip_archs}->{$package->arch()};

        $function->($File::Find::name, $package);
    };

    find($callback, $self->{_path});
}

sub traverse_headers {
    my ($self, $function) = @_;
    croak "Not a class method" unless ref $self;

    $self->{_urpm}->traverse(sub {
        $function->(Youri::Package::URPM->new(header => $_[0]));
    });
    
}

sub _get_file {
    my ($self, $file) = @_;

    if ($file =~ /^(?:http|ftp):\/\/.*$/) {
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

1;
