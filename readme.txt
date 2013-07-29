WormAI OpenTTD AI
=================

Introduction
------------
WormAI started as a fork of WrightAI and currently also supports only pax
air transport. Other types of transport are planned for a future release.
Several improvements to the original code have been made to make it
stand out enough to release it.
It doesn't do very well when infrastructure maintenance is on and also
doesn't have any specific code yet to handle renewing airplanes or
breakdowns. However, since low profit airplanes get sold it shouldn't
do totally bad in that situation.

License: see license.txt
Discussion topic: http://www.tt-forums.net/viewtopic.php?f=65&t=67167
Bug/Issue tracker: http://dev.openttdcoop.org/projects/ai-worm/issues
Source repository: http://dev.openttdcoop.org/projects/ai-worm/repository


Requirements
------------
OpenTTD 1.2 or later.
SuperLib and AILibList. I won't list the versions here since then I would
have to update this text everytime the versions change. However I have a
script that updates the library versions before a release of my AI so I
should always be using the latest versions at the time of release.


Features
--------
Building airports and managing airport routes connecting two airports.
Saving and loading are supported.
Aircraft maximum distance supported.
Handling of reaching maximum allowed aircraft.


Settings
--------
The following settings can be used. All except the thinking speed can be
changed during the game.

1. Enable aircraft [default: on]
   This setting turns on or off aircraft building. Since WormAI currently
   only supports air transport turning this off means WormAI will not do
   any new aircraft building nor any maintenance on it's airlines.

2. How fast this AI will think [default depends on AI competitor speed 
   setting]
   This setting regulates the thinking speed of WormAI. Slower speed means
   the AI will wait longer between building and managing airports and
   aircraft.

3. The minimum size of towns to be considered for getting an airport.
   [default depends on AI competitor speed setting]
   This setting tells WormAI the smallest town (population) where it
   is allowed to build an airport.

4. The minimum distance between airports.
   [default depends on AI competitor speed setting]
   This setting tells WormAI the minimum allowed distance between airports
   to build a route.

5. The maximum distance between airports.
   [default depends on AI competitor speed setting]
   This setting tells WormAI the maxnimum allowed distance between airports
   to build a route.


Current limits and shortcomings
-------------------------------
Only aircraft and only pax.
Not checking for breakdowns, reliability and autorenew settings and
orders don't include going to depot for servicing.
Airports do not get upgraded to newer types.
Every route consists of 2 airports, unconnected to other airports.
Only tested in temperate climate, not sure if it matters for pax
air transport.
Doesn't start building as fast as a lot of other AI's meaning that
in situations with a limited amount of suitable spots for airports
it might have a difficult time starting.


Wormnest (Jacob Boerema), July 2013
