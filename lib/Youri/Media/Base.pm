# $Id$
package Youri::Media::Base;

=head1 NAME

Youri::Media::Base - Abstract Media class

=head1 DESCRIPTION

This is the abstract Media class defining generic interface.

=cut

use Carp;
use strict;
use warnings;

=head1 CLASS METHODS

=head2 new(I<%hash>)

Returns a C<Youri::Media::Base> object.

Generic parameters:

=over

=item B<id>

id of this media.

=item B<test>

don't perform anything for real.

=item B<verbose>

verbosity level.

=item B<allow_deps>

list of ids of medias allowed to provide dependencies.

=item B<skip_inputs>

list of ids of inputs to be skipped.

=item B<skip_archs>

list of archs to be skipped.

=back

Warning: do not call directly, call subclass constructor instead.

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

=head1 INSTANCE METHODS

=head2 id()

Returns the id of this media.

=cut

sub id {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return $self->{_id};
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

=head2 allow_dep(I<$media_id>)

Tells wether media with id I<$media_id> is allowed to provide dependencies for
this media.

=cut

sub allow_dep {
    my ($self, $dep) = @_;
    croak "Not a class method" unless ref $self;

    return
        $self->{_allow_deps}->{all} ||
        $self->{_allow_deps}->{$dep};
}

=head2 skip_archs()

Returns the list of arch which are to be skipped for this media.

=cut

sub skip_archs {
    my ($self) = @_;
    croak "Not a class method" unless ref $self;

    return keys %{$self->{_skip_archs}};
}

=head2 skip_arch(I<$arch>)

Tells wether arch I<$arch> is to be skipped for this media.

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

=head2 skip_input(I<$input_id>)

Tells wether input with id I<$input_id> is to be skipped for this media.

=cut

sub skip_input {
    my ($self, $input) = @_;
    croak "Not a class method" unless ref $self;

    return
        $self->{_skip_inputs}->{all} ||
        $self->{_skip_inputs}->{$input};
}

=head2 traverse_files(I<$function>)

Apply function I<$function> to all files of this media.

=cut

sub traverse_files {
    croak "Not implemented";
}

=head2 traverse_headers(I<$function>)

Apply function I<$function> to all headers of this media.

=cut

sub traverse_headers {
    croak "Not implemented";
}

=head1 SUBCLASSING

B<traverse_headers> and B<traverse_files> are to be overrided, default
implementation dies immediatly.

=cut

1;
