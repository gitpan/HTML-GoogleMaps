=head1 NAME

HTML::GoogleMaps - a simple wrapper around the Google Maps API

=head1 SYNOPSIS

  $map = HTML::GoogleMaps->new(key => $map_key,
                               db => $geo_coder_us_db);
  $map->center(point => "1810 Melrose St, Madison, WI");
  $map->add_marker(point => "1210 W Dayton St, Madison, WI");
 
  my ($head, $body) = $map->render;

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

=item $map->add_marker(point => $point, html => $info_window_html)

Add a marker to the map at the given point.  If B<html> is specified,
add a popup info window as well.

=item $map->add_polyline(points => [ $point1, $point2 ])

Add a polyline that connects the list of points.  Other options
include B<color> (any valid HTML color), B<weight> (line width in
pixels) and B<opacity> (between 0 and 1).

=item $map->render

Renders the map and returns a two element list.  The first element
needs to be placed in the head section of your HTML document.  The
second in the body where you want the map to appear.

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

our $VERSION = 1;

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
    
    my $point = $this->_text_to_point($opts{point});
    return 0 unless $point;

    push @{$this->{points}}, { point => $point,
			       html => $opts{html} };
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
    $this->{center} ||= [ 0, 0 ];

    my $text = "
<div id=map style=\"width: $this->{width}px; height: $this->{height}px\"></div>
    <script type=text/javascript>
    //<![CDATA[

    if (GBrowserIsCompatible()) {
      var map = new GMap(document.getElementById(\"map\"));\n";

    $text .= "      map.centerAndZoom(new GPoint($this->{center}[0], $this->{center}[1]), $this->{zoom});\n"
	if $this->{center};

    #my $type = "G_" . uc($this->{type});
    #$text .= "      map.setMapType($type);\n";
    
    if ($this->{controls})
    {
	foreach my $control (@{$this->{controls}})
	{
	    $control =~ s/_(.)/uc($1)/ge;
	    $control = ucfirst($control);
	    $text .= "      map.addControl(new G${control}());\n";
	}
    }

    my $i;
    foreach my $point (@{$this->{points}})
    {
	$i++;
	$text .= "      var marker_$i = new GMarker(new GPoint($point->{point}[0], $point->{point}[1]));\n";
	$text .= "      GEvent.addListener(marker_$i, \"click\", function () {  marker_$i.openInfoWindowHtml(\"$point->{html}\"); });\n"
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

    return ("<script src=http://maps.google.com/maps?file=api&v=1&key=$this->{key} type=text/javascript></script>", $text);
}

1;
