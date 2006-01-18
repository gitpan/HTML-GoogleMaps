#!/usr/bin/env perl

use strict;
use lib "lib";
use HTML::GoogleMaps;

my $map = HTML::GoogleMaps->new(key => "ABQIAAAAGB86gU4u3NmKU2FE3zcGqxTxtdq1_9vdQ8IEOHasuVZDuDzfYhTQwjYRe92TzTh4MqZSvkVaWBEYXw");

$map->add_icon(name => "test",
	       shadow => "http://www.google.com/mapfiles/shadow50.png",
	       icon_size => [ 20, 34 ],
	       shadow_size => [ 37, 34 ],
	       image => "http://www.google.com/mapfiles/markerC.png");
$map->add_marker(point => [-160, 0], icon => "B");
$map->add_marker(point => [170, 0], icon => "J");
$map->add_marker(point => [170, 30], icon => "test");
$map->controls("large_map_control", "map_type_control");

my ($head, $body) = $map->render;
print "<html><head><title>GMap Test</title>$head</head><body>\n";
print $body;
print "</body></html>";

