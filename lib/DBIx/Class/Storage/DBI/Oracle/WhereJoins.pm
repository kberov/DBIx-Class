package DBIx::Class::Storage::DBI::Oracle::WhereJoins;

use base qw( DBIx::Class::Storage::DBI::Oracle::Generic );

use strict;
use warnings;

BEGIN {
  package DBIC::SQL::Abstract::Oracle;

  use base qw( DBIC::SQL::Abstract );

  sub select {
    my ($self, $table, $fields, $where, $order, @rest) = @_;

    $self->_oracle_joins($where, @{ $table });

    return $self->SUPER::select($table, $fields, $where, $order, @rest);
  }

  sub _recurse_from {
    my ($self, $from, @join) = @_;

    my @sqlf = $self->_make_as($from);

    foreach my $j (@join) {
      my ($to, $on) = @{ $j };

      if (ref $to eq 'ARRAY') {
        push (@sqlf, $self->_recurse_from(@{ $to }));
      }
      else {
        push (@sqlf, $self->_make_as($to));
      }
    }

    return join q{, }, @sqlf;
  }

  sub _oracle_joins {
    my ($self, $where, $from, @join) = @_;

    foreach my $j (@join) {
      my ($to, $on) = @{ $j };

      if (ref $to eq 'ARRAY') {
        $self->_oracle_joins($where, @{ $to });
      }

      my $to_jt      = ref $to eq 'ARRAY' ? $to->[0] : $to;
      my $left_join  = q{};
      my $right_join = q{};

      if (ref $to_jt eq 'HASH' and exists $to_jt->{-join_type}) {
        #TODO: Support full outer joins -- this would happen much earlier in
        #the sequence since oracle 8's full outer join syntax is best
        #described as INSANE.
        die "Can't handle full outer joins in Oracle 8 yet!\n"
          if $to_jt->{-join_type} =~ /full/i;

        $left_join  = q{(+)} if $to_jt->{-join_type} =~ /right/i
                             && $to_jt->{-join_type} !~ /inner/i;

        $right_join = q{(+)} if $to_jt->{-join_type} =~ /left/i
                             && $to_jt->{-join_type} !~ /inner/i;
      }

      foreach my $lhs (keys %{ $on }) {
        $where->{$lhs . $left_join} = \" = $on->{ $lhs }$right_join";
      }
    }
  }
}

sub sql_maker {
  my ($self) = @_;

  unless ($self->_sql_maker) {
    $self->_sql_maker(
      new DBIC::SQL::Abstract::Oracle( $self->_sql_maker_args )
    );
  }

  return $self->_sql_maker;
}

1;

__END__

=pod

=head1 NAME

DBIx::Class::Storage::DBI::Oracle::WhereJoins - Oracle joins in WHERE syntax
support (instead of ANSI).

=head1 PURPOSE

This module was originally written to support Oracle < 9i where ANSI joins
weren't supported at all, but became the module for Oracle >= 8 because
Oracle's optimising of ANSI joins is horrible.  (See:
http://scsys.co.uk:8001/7495)

=head1 SYNOPSIS

DBIx::Class should automagically detect Oracle and use this module with no
work from you.

=head1 DESCRIPTION

This class implements Oracle's WhereJoin support.  Instead of:

    SELECT x FROM y JOIN z ON y.id = z.id

It will write:

    SELECT x FROM y, z WHERE y.id = z.id

It should properly support left joins, and right joins.  Full outer joins are
not possible due to the fact that Oracle requires the entire query be written
to union the results of a left and right join, and by the time this module is
called to create the where query and table definition part of the sql query,
it's already too late.

=head1 METHODS

This module replaces a subroutine contained in DBIC::SQL::Abstract:

=over

=item sql_maker

=back

It also creates a new module in its BEGIN { } block called
DBIC::SQL::Abstract::Oracle which has the following methods:

=over

=item select ($\@$;$$@)

Replaces DBIC::SQL::Abstract's select() method, which calls _oracle_joins()
to modify the column and table list before calling SUPER::select().

=item _recurse_from ($$\@)

Recursive subroutine that builds the table list.

=item _oracle_joins ($$$@)

Creates the left/right relationship in the where query.

=back

=head1 BUGS

Does not support full outer joins.
Probably lots more.

=head1 SEE ALSO

=over

=item L<DBIC::SQL::Abstract>

=item L<DBIx::Class::Storage::DBI::Oracle::Generic>

=item L<DBIx::Class>

=back

=head1 AUTHOR

Justin Wheeler C<< <jwheeler@datademons.com> >>

=head1 CONTRIBUTORS

David Jack Olrik C<< <djo@cpan.org> >>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.

=cut
