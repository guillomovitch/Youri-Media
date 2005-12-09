# $Id$
package Youri::Media::Base;

=head1 NAME

Youri::Media::Base - Youri Base Media Class

=head1 DESCRIPTION

This module implements the base Media class

=cut


use Carp;
use strict;
use warnings;

=head2 new(I<$class>, I<option_name1, option_value1, ...>)

Instantiates a Base Media object.

=cut

sub new {
    my $class   = shift;
    my %options = (
        id             => '',    # object id
        test           => 0,     # test mode
        verbose        => 0,     # verbose mode
        allow_deps     => undef, # list of media ids from which deps are allowed
        skip_inputs    => undef, # list of inputs ids to skip
        skip_archs     => undef, # list of archs for which to skip tests
        @_
    );

    # some options need to be arrays. Check it and convert to hashes
    foreach my $option (qw(allow_deps skip_archs skip_inputs)) {
        next unless defined $options{$option};
        croak "$option should be an arrayref" unless ref $options{$option} eq 'ARRAY';
        $options{$option}  = {
            map { $_ => 1 } @{$options{$option}}
        };
    }

    my $self = bless {
        _id             => $options{id}, 
        _allow_deps     => $options{allow_deps}, 
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

=head2 id()

Returns the id of the Media

=cut

sub id {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_id};
}

=head2 allow_deps()

Returns the list of allowed dependant medias

=cut

sub allow_deps {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return keys %{$self->{_allow_deps}};
}

=head2 allow_dep(I<$media>)

tells wether the I<$media> is an allowed dependant media

=cut

sub allow_dep {
    my ($self, $dep) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_allow_deps}->{all} || $self->{_allow_deps}->{$dep};
}

=head2 skip_archs()

Returns the list of skipped archs

=cut

sub skip_archs {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return keys %{$self->{_skip_archs}};
}

=head2 skip_arch(I<$arch>)

tells wether the I<$arch> is skipped

=cut

sub skip_arch {
    my ($self, $arch) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_skip_archs}->{all} || $self->{_skip_archs}->{$arch};
}

=head2 skip_inputs()

returns the list of skipped inputs

=cut

sub skip_inputs {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return keys %{$self->{_skip_inputs}};
}

=head2 skip_input(I<$input>)

tells wether the I<$input> is skipped

=cut
sub skip_input {
    my ($self, $input) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_skip_inputs}->{all} || $self->{_skip_inputs}->{$input};
}

sub check_files {
    my ($self) = @_;
    croak "No check_files() method in class " . ref($self);

}

sub check_headers {
    my ($self) = @_;
    croak "No check_headers() method in class " . ref($self);

}

1;
