# $Id$
package Youri::Media::URPM;

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

sub max_age {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_max_age};
}

sub rpmlint_config {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_rpmlint_config};
}


sub check_files {
    my ($self, $check) = @_;
    croak "Not a class method" unless ref $self;

    my $callback = sub {
        return unless -f $File::Find::name;
        return unless -r $File::Find::name;
        return unless $_ =~ /\.rpm$/;

        # my $package = get_rpm($File::Find::name);
        my $package = Youri::Package::URPM->new(rpm_file => $File::Find::name);
        return if $self->{_skip_archs}->{$package->arch()};

        $check->($File::Find::name, $package);
    };

    find($callback, $self->{_path});
}

sub check_packages {
    my ($self, $check) = @_;
    croak "Not a class method" unless ref $self;

    # the media is traversed. Each rpm object is wrapped into Package before applying $check
    $self->{_urpm}->traverse(sub {
        $check->(Youri::Package::URPM->new(rpm_package => $_[0]));
    });
    
}

=head2 $media->find_packages_with_provide(I<$provide>)

Check if media has any package providing dependency I<$provide>.
Return a list of structures with the following fields:

=over

=item range

range of the dependency

=item package

package providing the dependency

=back

=cut

sub find_packages_with_provide {
    my ($self, $provide) = @_;
    croak "Not a class method" unless ref $self;

    $self->_index_provides() unless $self->{_provides};

    return $self->{_provides}->{$provide} ?
        @{$self->{_provides}->{$provide}} :
        ();
}

=head2 $media->find_packages_with_file(I<$file>)

Check if media has any package owning file I<$file>.
Return a list of structures with the following fields:

=over

=item package

package owning the file

=back

Return a list of structures.

=cut

sub find_packages_with_file {
    my ($self, $file) = @_;
    croak "Not a class method" unless ref $self;

    $self->_index_files() unless $self->{_files};

    return $self->{_files}->{$file} ?
        @{$self->{_files}->{$file}} :
        ();
}

sub _index_provides {
    my ($self) = @_;

    my %provides;
    my $fetch = sub {
        my ($package) = @_;
        foreach my $dep ($package->provides()) {
            my ($name, $range) = $dep =~ /^([^[]+)(?:\[(.+)\])?$/;
            push(@{$provides{$name}}, {
        	range   => $range ?
        	    $range eq '*' ?
        		undef :
        		$range :
        	    $range,
        	package => $package
            });
        }
    };

    $self->{_urpm}->traverse(sub {
        $fetch->(Youri::Package::URPM->new(rpm_package => $_[0]));
    });

    $self->{_provides} = \%provides;
}

sub _index_files {
    my ($self) = @_;

    my %files;
    my $fetch = sub {
        my ($package) = @_;

        my @modes   = $package->files_mode();
        my @md5sums = $package->files_md5sum();

        foreach my $file ($package->files()) {
            my $mode = shift @modes;
            my $md5sum = shift @md5sums;
            push(@{$files{$file}}, {
        	package => $package,
        	mode    => $mode,
        	md5sum  => $md5sum
            });
        }
    };

    $self->{_urpm}->traverse(sub {
        $fetch->(Youri::Package::URPM->new(rpm_package => $_[0]));
    });

    $self->{_files} = \%files;
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
