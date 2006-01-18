=head1 NAME

HTML::GoogleMaps - a simple wrapper around the Google Maps API

=head1 SYNOPSIS

  $map = HTML::GoogleMaps->new(key => $map_key,
                               db => $geo_coder_us_db);
  $map->center(point => "1810 Melrose St, Madison, WI");
  $map->add_marker(point => "1210 W Dayton St, Madison, WI");
 
  my ($head, $map_div, $map_script) = $map->render;

=head1 NOTE

This version is not API compatable with HTML::GoogleMaps versions 1
and 2.  The render method now returns three values instead of two.

=head1 DESCRIPTION

HTML::GoogleMaps provides a simple wrapper around the Google Maps
API.  It allows you to easily create maps with markers, polylines and
information windows.  If you have Geo::Coder::US installed, it will be
able to do basic geocoding for US addresses.

=head1 CONSTRUCTOR

=over 4

=item $map = HTML::GoogleMaps->new(key => $map_key);

Creates a new HTML::GoogleMaps object.  Takes a hash of options.  The
only required option is I<key>, which is your Google Maps API key.
You can get a key at http://maps.google.com/apis/maps/signup.html .
Other valid options are:

=over 4

=item db => Geo::Coder::US database

If given, the B<add_marker> and B<add_polyline> methods will be able
to map US addresses, as well as longitude/latitude pairs.

=item height => height in pixels

=item width => width in pixels

=back

=back

=head1 METHODS

=over 4

=item $map->center($point)

Center the map at a given point.

=item $map->zoom($level)

Set the zoom level

=item $map->controls($control1, $control2)

Enable the given controls.  Valid controls are: B<large_map_control>,
B<small_map_control>, B<small_zoom_control> and B<map_type_control>.

=item $map->dragging($enable)

Enable or disable dragging.

=item $map->info_window($enable)

Enable or disable info windows.

=item $map->map_type($type)

Set the map type.  Either B<map_type> or B<satellite_type>.

=item $map->add_icon(name => $icon_name,
                     image => $image_url,
                     shadow => $shadow_url,
                     image_size => [ $width, $height ],
                     shadow_size => [ $width, $height ]);

Adds a new icon, which can later be used by add_marker.  Optional args
include B<icon_anchor> and B<info_window_anchor>.

=item $map->add_marker(point => $point, html => $info_window_html)

Add a marker to the map at the given point.  If B<html> is specified,
add a popup info window as well.  B<icon> can be used to switch to
either a user defined icon (via the name) or a standard google letter
icon (A-J).

Any data given for B<html> is placed inside a 350px by 200px div to
make it fit nicely into the Google popup.  To turn this behavior off 
just pass B<noformat> => 1 as well.

=item $map->add_polyline(points => [ $point1, $point2 ])

Add a polyline that connects the list of points.  Other options
include B<color> (any valid HTML color), B<weight> (line width in
pixels) and B<opacity> (between 0 and 1).

=item $map->render

Renders the map and returns a three element list.  The first element
needs to be placed in the head section of your HTML document.  The
second in the body where you want the map to appear.  The third (the 
Javascript that controls the map) needs to be placed in the body,
but outside any div or table that the map lies inside.

=back

=head1 ONLINE EXAMPLE

L<http://www.cs.wisc.edu/~nmueller/fsbo_open_houses.pl>

=head1 SEE ALSO

L<http://maps.google.com/apis/maps/documentation>
L<http://geocoder.us>

=head1 AUTHORS

Nate Mueller <nate@cs.wisc.edu>

=cut

package HTML::GoogleMaps;

use strict;

our $VERSION = 3;

sub new
{
    my ($class, %opts) = @_;

    return 0
	unless $opts{key};

    if ($opts{db})
    {
	require Geo::Coder::US;
        Geo::Coder::US->set_db($opts{db});
    }
    
    bless { %opts,
	    points => [],
	    poly_lines => [] }, $class;
}

sub _text_to_point
{
    my ($this, $point_text) = @_;

    # IE, already a long/lat pair
    return $point_text if ref($point_text) eq "ARRAY";

    # US street address
    if ($this->{db})
    {
	my ($point) = Geo::Coder::US->geocode($point_text);
	if ($point->{lat})
	{
	    return [ $point->{long}, $point->{lat} ];
	}
    }

    # Unknown
    return 0;
}

=begin testing

use HTML::GoogleMaps;

$map = new HTML::GoogleMaps key => "foo";
$map->add_marker(point => [0, 0]);
is_deeply($map->_find_center, [0, 0], "Single point 1");

$map = new HTML::GoogleMaps key => "foo";
$map->add_marker(point => [90, 0]);
is_deeply($map->_find_center, [90, 0], "Single point 2");

$map = new HTML::GoogleMaps key => "foo";
$map->add_marker(point => [180, 45]);
is_deeply($map->_find_center, [180, 45], "Single point 3");

$map = new HTML::GoogleMaps key => "foo";
$map->add_marker(point => [-90, -10]);
is_deeply($map->_find_center, [-90, -10], "Single point 4");

$map = new HTML::GoogleMaps key => "foo";
$map->add_marker(point => [10, 10]);
$map->add_marker(point => [20, 20]);
is_deeply($map->_find_center, [15, 15], "Double point 1");

$map = new HTML::GoogleMaps key => "foo";
$map->add_marker(point => [-10, 10]);
$map->add_marker(point => [-20, 20]);
is_deeply($map->_find_center, [-15, 15], "Double point 2");

$map = new HTML::GoogleMaps key => "foo";
$map->add_marker(point => [10, 10]);
$map->add_marker(point => [-10, -10]);
is_deeply($map->_find_center, [0, 0], "Double point 3");

$map = new HTML::GoogleMaps key => "foo";
$map->add_marker(point => [-170, 0]);
$map->add_marker(point => [150, 0]);
is_deeply($map->_find_center, [170, 0], "Double point 4");

=end testing

=cut

sub _find_center
{
    my ($this) = @_;

    my $total_lat;
    my $total_long;
    my $total_abs_long;
    foreach my $point (@{$this->{points}})
    {
	$total_lat += $point->{point}[1];
	$total_long += $point->{point}[0];
	$total_abs_long += abs($point->{point}[0]);
    }
    
    # Latitude is easy, just an average
    my $center_lat = $total_lat/@{$this->{points}};
    
    # Longitude, on the other hand, is trickier.  If points are
    # clustered around the international date line a raw average
    # would produce a center around longitude 0 instead of -180.
    my $avg_long = $total_long/@{$this->{points}};
    my $avg_abs_long = $total_abs_long/@{$this->{points}};
    return [ $avg_long, $center_lat ]       # All points are on the
	if abs($avg_long) == $avg_abs_long; # same hemasphere

    if ($avg_abs_long > 90) # Closer to the IDL
    {
	if ($avg_long < 0 && abs($avg_long) <= 90)
	{
	    $avg_long += 180;
	}
	elsif (abs($avg_long) <= 90)
	{
	    $avg_long -= 180;
	}
    }

    return [ $avg_long, $center_lat ];
}

sub center
{
    my ($this, $point_text) = @_;

    my $point = $this->_text_to_point($point_text);
    return 0 unless $point;
    
    $this->{center} = $point;
    return 1;
}

sub zoom
{
    my ($this, $zoom_level) = @_;

    $this->{zoom} = $zoom_level;
}

sub controls
{
    my ($this, @controls) = @_;

    my %valid_controls = map { $_ => 1 } qw(large_map_control
					    small_map_control
					    small_zoom_control
					    map_type_control);
    return 0 if grep { !$valid_controls{$_} } @controls;

    $this->{controls} = [ @controls ];
}

sub dragging
{
    my ($this, $dragging) = @_;

    $this->{dragging} = $dragging;
}

sub info_window
{
    my ($this, $info) = @_;

    $this->{info_window} = $info;
}

sub map_type
{
    my ($this, $type) = @_;

    my %valid_types = map { $_ => 1 } qw(map_type
					 satellite_type);
    return 0 unless $valid_types{$type};

    $this->{type} = $type;
}

sub add_marker
{
    my ($this, %opts) = @_;
    
    return 0 if $opts{icon} && $opts{icon} !~ /^[A-J]$/
	&& !$this->{icon_hash}{$opts{icon}};

    my $point = $this->_text_to_point($opts{point});
    return 0 unless $point;

    push @{$this->{points}}, { point => $point,
			       icon => $opts{icon},
			       html => $opts{html},
			       format => !$opts{noformat} };
}

sub add_icon
{
    my ($this, %opts) = @_;

    return 0 unless $opts{image} && $opts{shadow} && $opts{name};
    
    $this->{icon_hash}{$opts{name}} = 1;
    push @{$this->{icons}}, \%opts;
}

sub add_polyline
{
    my ($this, %opts) = @_;

    my @points = map { $this->_text_to_point($_) } @{$opts{points}};
    return 0 if grep { !$_ } @points;

    push @{$this->{poly_lines}}, { points => \@points,
				   color => $opts{color} || "\#0000ff",
				   weight => $opts{weight} || 5,
				   opacity => $opts{opacity} || .5 };
}

sub render
{
    my ($this) = @_;

    # Add in all the defaults
    $this->{height} ||= 400;
    $this->{width} ||= 600;
    $this->{dragging} = 1 unless defined $this->{dragging};
    $this->{info_window} = 1 unless defined $this->{info_window};
    $this->{type} ||= "map_type";
    $this->{zoom} ||= 4;
    $this->{center} ||= $this->_find_center;

    my $map = "
<div id=map style=\"width: $this->{width}px; height: $this->{height}px\"></div>";

    my $text = "
    <script type=text/javascript>
    //<![CDATA[

    if (GBrowserIsCompatible()) {
      var map = new GMap(document.getElementById(\"map\"));\n";

    $text .= "      map.centerAndZoom(new GPoint($this->{center}[0], $this->{center}[1]), $this->{zoom});\n"
	if $this->{center};

    my $type = "G_" . uc($this->{type});
    $text .= "      map.setMapType($type);\n";
    
    if ($this->{controls})
    {
	foreach my $control (@{$this->{controls}})
	{
	    $control =~ s/_(.)/uc($1)/ge;
	    $control = ucfirst($control);
	    $text .= "      map.addControl(new G${control}());\n";
	}
    }
    $text .= "\n";

    # Add in "standard" icons
    my %icons = map { $_->{icon} => 1 } grep { $_->{icon} =~ /^([A-J])$/; } @{$this->{points}};
    foreach my $icon (keys %icons)
    {
	$text .= "      var icon_$icon = new GIcon();
      icon_$icon.shadow = \"http://www.google.com/mapfiles/shadow50.png\";
      icon_$icon.iconSize = new GSize(20, 34);
      icon_$icon.shadowSize = new GSize(37, 34);
      icon_$icon.iconAnchor = new GPoint(9, 34);
      icon_$icon.infoWindowAnchor = new GPoint(9, 2);
      icon_$icon.image = \"http://www.google.com/mapfiles/marker$icon.png\";\n\n"
    }

    # And the rest
    foreach my $icon (@{$this->{icons}})
    {
	$text .= "      var icon_$icon->{name} = new GIcon();\n";
	$text .= "      icon_$icon->{name}.shadow = \"$icon->{shadow}\"\n"
	    if $icon->{shadow};
	$text .= "      icon_$icon->{name}.iconSize = new GSize($icon->{icon_size}[0], $icon->{icon_size}[1]);\n"
	    if ref($icon->{icon_size}) eq "ARRAY";
	$text .= "      icon_$icon->{name}.shadowSize = new GSize($icon->{shadow_size}[0], $icon->{shadow_size}[1]);\n"
	    if ref($icon->{shadow_size}) eq "ARRAY";
	$text .= "      icon_$icon->{name}.iconAnchor = new GPoint($icon->{icon_anchor}[0], $icon->{icon_anchor}[1]);\n"
	    if ref($icon->{icon_anchor}) eq "ARRAY";
	$text .= "      icon_$icon->{name}.infoWindowAnchor = new GPoint($icon->{info_window_anchor}[0], $icon->{info_window_anchor}[1]);\n"
	    if ref($icon->{info_window_anchor}) eq "ARRAY";
	$text .= "      icon_$icon->{name}.image = \"$icon->{image}\";\n\n";
    }
    
    my $i;
    foreach my $point (@{$this->{points}})
    {
	$i++;
	
	$point->{icon} =~ s/(.+)/icon_$1/;
	my $icon = ", $point->{icon}"
	    if $point->{icon};

	my $point_html = $point->{html};
	if ($point->{format})
	{
	    $point_html = "<div style='width:350px;height:200px;'>$point->{html}</div>";
	}

	$text .= "      var marker_$i = new GMarker(new GPoint($point->{point}[0], $point->{point}[1]) $icon);\n";
	$text .= "      GEvent.addListener(marker_$i, \"click\", function () {  marker_$i.openInfoWindowHtml(\"$point_html\"); });\n"
	    if $point->{html};
	$text .= "      map.addOverlay(marker_$i);\n";
    }

    $i = 0;
    foreach my $polyline (@{$this->{poly_lines}})
    {
	$i++;
	my $points = "[" . join(", ", map { "new GPoint($_->[0],
    $_->[1])" } @{$polyline->{points}}) . "]";
	$text .= "      var polyline_$i = new GPolyline($points,
    \"$polyline->{color}\", $polyline->{weight}, $polyline->{opacity});\n";
	$text .= "      map.addOverlay(polyline_$i);\n";
    }

    $text .= "    }

    //]]>
    </script>";

    return ("<script src=http://maps.google.com/maps?file=api&v=1&key=$this->{key} type=text/javascript></script>", $map, $text);
}

1;
