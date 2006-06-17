#!/usr/bin/perl -w

use Test::More 'no_plan';
use strict;
use blib;

BEGIN { use_ok('HTML::GoogleMaps') }
use HTML::GoogleMaps;

# Autocentering
{
  my $map = HTML::GoogleMaps->new(key => 'foo');
  $map->add_marker(point => [0, 0]);
  is_deeply( $map->_find_center, [0, 0], "Single point 1" );

  $map = HTML::GoogleMaps->new(key => 'foo');
  $map->add_marker(point => [90, 0]);
  is_deeply( $map->_find_center, [0, 90], "Single point 2" );

  $map = HTML::GoogleMaps->new(key => 'foo');
  $map->add_marker(point => [180, 45]);
  is_deeply( $map->_find_center, [45, 180], "Single point 3" );

  $map = HTML::GoogleMaps->new(key => 'foo');
  $map->add_marker(point => [-90, -10]);
  is_deeply( $map->_find_center, [-10, -90], "Single point 4" );

  $map = HTML::GoogleMaps->new(key => 'foo');
  $map->add_marker(point => [10, 10]);
  $map->add_marker(point => [20, 20]);
  is_deeply( $map->_find_center, [15, 15], "Double point 1" );

  $map = HTML::GoogleMaps->new(key => 'foo');
  $map->add_marker(point => [-10, 10]);
  $map->add_marker(point => [-20, 20]);
  is_deeply( $map->_find_center, [15, -15], "Double point 2" );

  $map = HTML::GoogleMaps->new(key => 'foo');
  $map->add_marker(point => [10, 10]);
  $map->add_marker(point => [-10, -10]);
  is_deeply( $map->_find_center, [0, 0], "Double point 3" );

  $map = HTML::GoogleMaps->new(key => 'foo');
  $map->add_marker(point => [-170, 0]);
  $map->add_marker(point => [150, 0]);
  is_deeply( $map->_find_center, [0, 170], "Double point 4" );
}

# API v2 support
{
  my $map = HTML::GoogleMaps->new(key => 'foo');
  my ($head, $html, $ctrl) = $map->render;
  like( $head, qr/script.*v=2/, 'Point to v2 API' );

  like( $ctrl, qr/Zoom.*13/, 'Proper v2 default zoom' );
  $map->zoom(2);
  is( $map->{zoom}, 15, 'v1 zoom function translates' );
  $map->v2_zoom(3);
  is( $map->{zoom}, 3, 'v2 zoom function works as expected' );
    
  $map->center([12,13]);
  $map->add_marker(point => [13,14]);
  $map->add_polyline(points => [ [14,15], [15,16] ]);
  ($html, $head, $ctrl) = $map->render;
  like( $ctrl, qr/setCenter.*GLatLng\(13, 12\)/, 
    'GLatLng for centering' );
  like( $ctrl, qr/GMarker\(new GLatLng\(14, 13\)/, 
    'GLatLng for points' );
  like( $ctrl, qr/GPolyline\(\[new GLatLng\(15, 14\)/, 
    'GLatLng for polylines' );

  like( $ctrl, qr/setMapType\(G_NORMAL_MAP\)/, 'Proper v1 default type' );
  $map->map_type('map_type');
  ($html, $head, $ctrl) = $map->render;
  like( $ctrl, qr/setMapType\(G_NORMAL_MAP\)/, 'Old map_type' );
  $map->map_type('satellite_type');
  ($html, $head, $ctrl) = $map->render;
  like( $ctrl, qr/setMapType\(G_SATELLITE_MAP\)/, 'Old satellite_type' );
  $map->map_type('normal');
  ($html, $head, $ctrl) = $map->render;
  like( $ctrl, qr/setMapType\(G_NORMAL_MAP\)/, 'New normal type' );
  $map->map_type('satellite');
  ($html, $head, $ctrl) = $map->render;
  like( $ctrl, qr/setMapType\(G_SATELLITE_MAP\)/, 'New satellite type' );
  $map->map_type('hybrid');
  ($html, $head, $ctrl) = $map->render;
  like( $ctrl, qr/setMapType\(G_HYBRID_MAP\)/, 'New hybrid type' );

  like( $ctrl, qr/GMap2\(/, 'Use new GMap2 class' );
}

# Geo::Coder::Google
{
  my $stub_loc;
  my $map = HTML::GoogleMaps->new(key => 'foo');
  no warnings 'redefine';
  *Geo::Coder::Google::geocode = sub { +{Point => {coordinates => $stub_loc}} };
    
  $stub_loc = [3463, 3925, 0];
  $map->add_marker(point => 'result_democritean');
  my ($html, $head, $ctrl) = $map->render;
  like( $ctrl, qr/GMarker\(new GLatLng\(3925, 3463\)/, 
    'Geocoding with Geo::Coder::Google' );
}
