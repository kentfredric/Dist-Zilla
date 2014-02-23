package Dist::Zilla::Plugin::PkgReleaseStatus;

# ABSTRACT: Inject a $RELEASE_STATUS variable in your distribution

# AUTHORITY

use Moose;
with(
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [ ':InstallModules', ':ExecFiles' ],
    },
    'Dist::Zilla::Role::PPI',
);
use Moose::Util::TypeConstraints qw(enum);

use PPI;
use namespace::autoclean;

sub munge_files {
    my ( $self ) = @_;
    $self->munge_file($_) for @{ $self->found_files };
}

sub munge_file {
  my ($self, $file) = @_;

  if ($file->is_bytes) {
    $self->log_debug($file->name . " has 'bytes' encoding, skipping...");
    return;
  }

  return $self->munge_perl($file);
}

has die_on_no_version => (
  is => 'ro',
  isa => 'Bool',
  default => 0,
);

has die_on_existing_status => (
  is  => 'ro',
  isa => 'Bool',
  default => 0,
);

has die_on_line_insertion => (
  is  => 'ro',
  isa => 'Bool',
  default => 0,
);

has _release_status => (
  is => 'ro',
  isa => enum(['stable','testing']),
  lazy_build => 1,
);

sub _build__release_status {
  my ( $self ) = @_;
  return 'testing' if $self->zilla->is_trial;
  return 'testing' if $self->zilla->version =~ /_/;
  return 'stable';
}

sub _injection_for {
  my ( $self, $package ) = @_;
  return sprintf q[$%s::RELEASE_STATUS%s'%s';], $package, q[ = ], $self->_release_status;
}

sub _has_release_status_token {
  my ( $self, $document, $file ) = @_;

  return unless  $self->document_assigns_to_variable( $document, '$RELEASE_STATUS' );
  $self->log_fatal([ 'existing assignment to $RELEASE_STATUS in %s', $file->name ])
    if  $self->die_on_existing_status;

  $self->log([ 'skipping %s: assigns to $RELEASE_STATUS', $file->name ]);
  return 1;
}

sub _has_version_token {
  my ( $self, $document, $file ) = @_;
  return 1 if $self->document_assigns_to_variable( $document, '$VERSION' );
  $self->log_fatal(['Could not find $VERSION declaration to follow in %s', $file->name ])
    if $self->die_on_no_version;
  return;
}

sub _skip_package {
  my ( $self, $seen, $package , $stmt , $file ) = @_;
  if ( $seen->{$package}++ ) {
    $self->log([ 'skipping package re-declaration for %s', $package ]);
    return 1;
  }
  if ($stmt->content =~ /package\s*(?:#.*)?\n\s*\Q$package/) {
      $self->log([ 'skipping private package %s in %s', $package, $file->name ]);
      return 1;
  }
  return;
}
sub _next_line {
  my ( $self, $document, $current ) = @_;
  my $find = $document->find(sub{
    return if not $_[1]->line_number;
    return if not $current->line_number;
    return $_[1]->line_number == $current->line_number + 1;
    return;
  });
  return $find;
}
sub _find_blank {
  my ( $self, $document, $start ) = @_;
  my $blank;
  my $curr = $start;
  while (1) {
    my $find = $self->_next_line($document,$curr);

    last unless $find and @{$find} == 1;

    if ( $find->[0]->isa('PPI::Token::Comment')) {
      $curr = $find->[0];
      next;
    }
    if ( "$find->[0]" =~ /\A\s*\z/ ) {
      return $find->[0];
    }
    return;
  }
}
sub _find_version_token {
  my ( $self, $document, $start ) = @_;
  my $blank;
  my $curr = $start;
  while (1) {
    my $find = $self->_next_line($document,$curr);

    last unless $find and @{$find};

    if ( $find->[0]->isa('PPI::Token::Comment')) {
      $curr = $find->[0];
      next;
    }

    if ( $find->[0]->isa('PPI::Statement') ) {
        my $token = $find->[0];
        if ( $token->content =~  /(?<!\\)(\$|::)VERSION\s*=/sm ) {
              return $token;
        }
    }
    if ( "$find->[0]" =~ /\A\s*\z/ ) {
      $curr = $find->[0];
      next;
    }
    return;
  }
}

sub munge_perl {
  my ( $self, $file ) = @_;
  my $document = $self->ppi_document_for_file($file);

  return if $self->_has_release_status_token( $document, $file );

  my $has_version =  $self->_has_version_token( $document, $file );

  my $package_stmts = $document->find('PPI::Statement::Package');
  unless ($package_stmts) {
    $self->log([ 'skipping %s: no package statement found', $file->name ]);
    return;
  }

  my %seen_pkg;
  my $munged = 0;
  for my $stmt ( @{$package_stmts} ) {
    my $package = $stmt->namespace;

    next if $self->_skip_package( \%seen_pkg, $package, $stmt , $file );

    my $version = $self->_find_version_token( $document, $stmt );

    if ( not $version ) {
      $self->log_debug([
        'skipping %s package %s: not $VERSION token found', $file->name, $package
      ]);
      next;
    }

    $self->log_debug([
      'adding $RELEASE_STATUS assignment to %s in %s',
      $package,
      $file->name,
    ]);
    my $blank = $self->_find_blank( $document, $version );

    my $injection = $self->_injection_for( $package );

    $injection = $blank ? "$injection\n" : "\n$injection";

    my $bogus_token = PPI::Token::Comment->new($injection);

    my $target = $version;

    if ( $blank ) {
      $target = $blank;
    } else {
      my $method = $self->die_on_line_insertion ? 'log_fatal' : 'log';
      $self->$method([
        'no blank line for $RELEASE_STATUS after $VERSION statement on %s line %s',
        $file->name,
        $version->line_number,
      ]);
    }

    Carp::carp("error inserting version in " . $file->name) unless
      $target->insert_after($bogus_token);

    if ( $blank ) {
      $blank->delete;
    }

    $munged  = 1;
  }
  $self->save_ppi_document_to_file($document,$file) if $munged;
}

__PACKAGE__->meta->make_immutable;
1;

