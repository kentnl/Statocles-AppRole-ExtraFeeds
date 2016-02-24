use 5.006;    # our
use strict;
use warnings;

package Statocles::AppRole::ExtraFeeds;

our $VERSION = '0.001000';

# ABSTRACT: Generate additional feed sets for apps

# AUTHORITY

use Statocles::Base 0.070 qw(Role);    # 0.70 required for ->template
use Statocles::Page::List;
use namespace::autoclean;

has 'extra_feeds' => (
  is      => 'ro',
  lazy    => 1,
  default => sub { {} },
);

sub _generate_feed {
  my ( $self, %iargs ) = @_;
  my %args;
  for my $required (qw( index path template index_title text )) {
    die "_generate_feed required param $required" unless exists $iargs{$required};
    $args{$required} = delete $iargs{$required};
  }
  die "_generate_feed got bad arg '$_'" for keys %iargs;
  my $feed = Statocles::Page::List->new(
    app      => $self,
    pages    => $args{'index'}->pages,
    path     => $args{'path'},
    template => $self->template( $args{'template'} ),
    links    => {
      alternate => [
        $self->link(
          href  => $args{'index'}->path,
          title => $args{'index_title'},
          type  => $args{'index'}->type,
        ),
      ]
    }
  );
  my $link_to_feed = $self->link(
    text => $args{text},
    href => $feed->path->stringify,
    type => $feed->type,
  );
  return ( $feed, $link_to_feed );
}

sub _derive_feed_path {
  my ( $self, $path, $feed_path ) = @_;
  if ( $path =~ /\A(.*)\/index\.(\w+)\z/ ) {
    return "$1/$feed_path";
  }
  if ( $path =~ qr{\A(.*)/([^/.]+)\.(\w+)\z} ) {
    return "$1/$2.$feed_path";
  }
  die "Don't know how to derive feed path from $path to $feed_path";
}

around pages => sub {
  my ( $orig, $self, @rest ) = @_;
  my (@pages) = $self->$orig(@rest);

  return @pages unless @pages;

  my @out_pages;

  while (@pages) {
    my $page = shift @pages;

    push @out_pages, $page;

    my (@existing_feeds) = $page->links('feed');

    next if not @existing_feeds;

    for my $feed_id ( sort keys %{ $self->extra_feeds } ) {
      my $feed = $self->extra_feeds->{$feed_id};

      my $feed_page = Statocles::Page::List->new(
        app      => $self,
        pages    => $page->pages,
        path     => $self->_derive_feed_path( $existing_feeds[0]->href, $feed->{name} || $feed_id ),
        template => $self->template( $feed->{template} || $feed->{name} || $feed_id ),
        links    => {
          alternate => [
            $self->link(
              href  => $page->path,
              title => ( $feed->{'index_title'} || "Feed" ),
              type  => $page->type,
            ),
          ]
        }
      );
      my $feed_link = $self->link(
        text => $feed->{text},
        href => $feed_page->path->stringify,
        type => $feed_page->type,
      );
      $page->links( feed => $feed_link );
      push @out_pages, $feed_page;
    }
  }
  return @out_pages;

};

  1;

=head1 DESCRIPTION

This module is a role that can be applied to any C<Statocles::App> in a C<Statocles>'s C<Beam::Wire>
configuration.

  ...
  blog_app:
    class: 'Statocles::App::Blog'
    with: 'Statocles::AppRole::ExtraFeeds'
    args:
      url_root: '/blog'
      # ... more Statocles::App::Blog args
      extra_feeds:
        fulltext.rss:
          text: "RSS FullText"

This example creates a feed called C</blog/fulltext.rss> containing the contents of C<theme/blog/fulltext.rss.ep>
after template application, and is linked from every C<index> listing.

It also creates a feed called C<< /blog/tag/<%= tagname %>.fulltext.rss >> for each tag, provisioned from the same template.

=head1 PARAMETERS

=head2 C<extra_feeds>

This Role provides one tunable parameter on its applied class, C<extra_feeds>, which contains a
mapping of 

  id => spec

=head3 C<extra_feeds> spec.

  {
    text      => required
    name      => default( id )
    template  => default( id )
  }

=head4 C<text>

This is the name of the feed when shown in links on both C<index> and C<tag index> pages.

=head4 C<template>

This is the name of the template to render the feeds content into.

Defaults to taking the same value as the key in the C<extra_fields> hash.

=head4 C<name>

This is the name of the file/file suffix that is generated.

It defaults to the same value as the key in the C<extra_feeds>
hash.

So:

  extra_feeds:
    fulltext.rss:
      text: "My FullText RSS"

And

  extra_feeds:
    genericlabel:
      text: "My FullText RSS"
      name: 'fulltext.rss'      # output name
      template: 'fulltext.rss'  # source template

Should both generate the same result.
