#!/usr/bin/perl -w

use Test::More 'no_plan';

package Catch;

sub TIEHANDLE {
    my($class, $var) = @_;
    return bless { var => $var }, $class;
}

sub PRINT  {
    my($self) = shift;
    ${'main::'.$self->{var}} .= join '', @_;
}

sub OPEN  {}    # XXX Hackery in case the user redirects
sub CLOSE {}    # XXX STDERR/STDOUT.  This is not the behavior we want.

sub READ {}
sub READLINE {}
sub GETC {}
sub BINMODE {}

my $Original_File = 'lib/HTML/GoogleMaps.pm';

package main;

# pre-5.8.0's warns aren't caught by a tied STDERR.
$SIG{__WARN__} = sub { $main::_STDERR_ .= join '', @_; };
tie *STDOUT, 'Catch', '_STDOUT_' or die $!;
tie *STDERR, 'Catch', '_STDERR_' or die $!;

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 167 lib/HTML/GoogleMaps.pm

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


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

