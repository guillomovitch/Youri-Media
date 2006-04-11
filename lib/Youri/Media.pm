# $Id$
package Youri::Media;

=head1 NAME

Youri::Media - Abstract media class

=head1 DESCRIPTION

This abstract class defines Youri::Media interface.

=cut

use Carp;
use strict;
use warnings;

=head1 CLASS METHODS

=head2 new(%args)

Creates and returns a new Youri::Media object.

Generic parameters:

=over

=item id $id

Media id.

=item name $name

Media name.

=item type $type (source/binary)

Media type.

=item test true/false

Test mode (default: false).

=item verbose true/false

Verbose mode (default: false).

=item allow_deps $media_ids

list of ids of medias allowed to provide dependencies.

=item skip_inputs $input_ids

list of ids of input plugins to skip.

=item skip_archs $arches

list of arches to skip.

=back

Subclass may define additional parameters.

Warning: do not call directly, call subclass constructor instead.

=cut

sub new {
    my $class = shift;
    croak "Abstract class" if $class eq __PACKAGE__;

    my %options = (
        name           => '',    # media name
        canonical_name => '',    # media canonical name
        type           => '',    # media type
        test           => 0,     # test mode
        verbose        => 0,     # verbose mode
        allow_deps     => undef, # list of media ids from which deps are allowed
        allow_srcs     => undef, # list of media ids from which packages can be built		
        skip_inputs    => undef, # list of inputs ids to skip
        skip_archs     => undef, # list of archs for which to skip tests
        @_
    );


    croak "No type given" unless $options{type};
    croak "Wrong value for type: $options{type}"
        unless $options{type} =~ /^(?:binary|source)$/o;

    # some options need to be arrays. Check it and convert to hashes
    foreach my $option (qw(allow_deps allow_srcs skip_archs skip_inputs)) {
        next unless defined $options{$option};
        croak "$option should be an arrayref" unless ref $options{$option} eq 'ARRAY';
        $options{$option}  = {
            map { $_ => 1 } @{$options{$option}}
        };
    }

    my $self = bless {
        _id             => $options{id}, 
        _name           => $options{name} || $options{id}, 
        _type           => $options{type}, 
        _allow_deps     => $options{allow_deps}, 
        _allow_srcs     => $options{allow_srcs},
        _skip_archs     => $options{skip_archs},
        _skip_inputs    => $options{skip_inputs},
    }, $class;

    $self->_init(%options);

    # remove unwanted archs
    if ($options{skip_archs}->{all}) {
        $self->_remove_all_archs()
    } elsif ($options{skip_archs}) {
        $self->_remove_archs($options{skip_archs});
    }

    return $self;
}

sub _init {
    # do nothing
}

=head1 INSTANCE METHODS

=head2 get_id()

Returns media identity.

=cut

sub get_id {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_id};
}

=head2 get_name()

Returns the name of this media.

=cut

sub get_name {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_name};
}

=head2 get_type()

Returns the type of this media.

=cut

sub get_type {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_type};
}

=head2 allow_deps()

Returns the list of id of medias allowed to provide dependencies for this
media. 

=cut

sub allow_deps {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return keys %{$self->{_allow_deps}};
}

=head2 allow_dep($media_id)

Tells wether media with given id is allowed to provide dependencies for
this media.

=cut

sub allow_dep {
    my ($self, $dep) = @_;
    croak "Not a class method" unless ref $self;

    return
        $self->{_allow_deps}->{all} ||
        $self->{_allow_deps}->{$dep};
}

=head2 allow_srcs()

Returns the list medias where the source packages can be

=cut

sub allow_srcs {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return keys %{$self->{_allow_srcs}};
}

=head2 allow_src($media_id)

Tells wether media with given id is allowed to host sources dependencies for
this media.

=cut

sub allow_src {
    my ($self, $src) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_allow_srcs}->{all} || $self->{_allow_srcs}->{$src};
}

=head2 skip_archs()

Returns the list of arch which are to be skipped for this media.

=cut

sub skip_archs {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return keys %{$self->{_skip_archs}};
}

=head2 skip_arch($arch)

Tells wether given arch is to be skipped for this media.

=cut

sub skip_arch {
    my ($self, $arch) = @_;
    croak "Not a class method" unless ref $self;

    return
        $self->{_skip_archs}->{all} ||
        $self->{_skip_archs}->{$arch};
}

=head2 skip_inputs()

Returns the list of id of input which are to be skipped for this media.

=cut

sub skip_inputs {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return keys %{$self->{_skip_inputs}};
}

=head2 skip_input($input_id)

Tells wether input with given id is to be skipped for this media.

=cut

sub skip_input {
    my ($self, $input) = @_;
    croak "Not a class method" unless ref $self;

    return
        $self->{_skip_inputs}->{all} ||
        $self->{_skip_inputs}->{$input};
}

=head2 get_package_class()

Return package class for this media.

=head2 traverse_files($function)

Apply given function to all files of this media.

=head2 traverse_headers($function)

Apply given function to all headers of this media.

=head1 SUBCLASSING

The following methods have to be implemented:

=over

=item traverse_headers

=item traverse_files

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002-2006, YOURI project

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
