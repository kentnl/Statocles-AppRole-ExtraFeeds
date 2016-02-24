use 5.006;    # our
use strict;
use warnings;

package Statocles::AppRole::ExtraFeeds;

our $VERSION = '0.001000';

# ABSTRACT: Generate additional feed sets for apps

# AUTHORITY

use Statocles::Base 0.070 qw(Role); # 0.70 required for ->template
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
  for my $required ( qw( index path template index_title text ) ) {
    die "_generate_feed required param $required" unless exists $iargs{$required};
    $args{$required} = delete $iargs{$required};
  }
  die "_generate_feed got bad arg '$_'" for keys %iargs;
  my $feed = Statocles::Page::List->new(
    app      => $self,
    pages    => $args{'index'}->pages,
    path     => $self->url_root . '/' . $args{'path'},
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

around index => sub {
  my ( $orig, $self, @arg ) = @_;
  my (@pages) = $self->$orig(@arg);
  return unless @pages;

  my $index = $pages[0];

  my ( @feed_pages, @feed_links );
  for my $feed_id ( sort keys %{ $self->extra_feeds } ) {
    my $feed = $self->extra_feeds->{$feed_id};
    my ( $feed_page, $feed_link ) = $self->_generate_feed(
      index       => $index,
      path        => ( $feed->{name} || $feed_id ),
      index_title => 'index',
      template    => ( $feed->{name} || $feed_id ),
      %{$feed}
    );
    push @feed_pages, $feed_page;
    for my $page (@pages) {
      next unless scalar $page->links('feed');
      $page->links( 'feed' => $feed_link );
    }
  }
  return ( @pages, @feed_pages );
};

around tag_pages => sub {
  my ( $orig, $self, $tagged_docs, @rest ) = @_;
  my (@pages) = $self->$orig( $tagged_docs, @rest );
  for my $tag ( keys %{$tagged_docs} ) {

    my (@tag_pages);
    my $epath = join '/', $self->url_root, 'tag', $self->_tag_url($tag), '';
    for my $page (@pages) {
      next unless $page->path =~ /^\Q$epath\E/;
      push @tag_pages, $page;
    }
    next unless @tag_pages;
    my ($index) = $tag_pages[0];    ## This seems really dodgy
    my ( @feed_pages, @feed_links );
    for my $feed_id ( sort keys %{ $self->extra_feeds } ) {
      my $feed = $self->extra_feeds->{$feed_id};
      my ( $feed_page, $feed_link ) = $self->_generate_feed(
        index       => $index,
        index_title => $tag,
        path        => ( 'tag/' . $self->_tag_url($tag) . '.' . ( $feed->{name} || $feed_id ) ),
        template => ( $feed->{name} || $feed_id ),
        %{$feed}
      );
      push @feed_pages, $feed_page;
      for my $page (@tag_pages) {
        #  $page->links( feed => $feed_link );
      }
    }
    push @pages, @feed_pages;
  }
  return @pages;
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
