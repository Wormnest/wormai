WormAI OpenTTD AI
=================

Introduction
------------
WormAI started as a fork of WrightAI and currently also supports only pax
air transport. Other types of transport are planned for a future release.
A lot of changes and improvements to the original code have been made
since then. It should do fairly well as long as you allow a reasonable
amount of aircraft and haven't turned on infrastruture maintenance.
Please report crashes and other bugs either in the discussion topic
or the issue tracker listed below.

License: see license.txt
Discussion topic: http://www.tt-forums.net/viewtopic.php?f=65&t=67167
Bug/Issue tracker: http://dev.openttdcoop.org/projects/ai-worm/issues
Source repository: http://dev.openttdcoop.org/projects/ai-worm/repository


Requirements
------------
OpenTTD 1.4 or later.
SuperLib, AILibList and AILibCommon (used by AILibList).
I won't list the versions here since then I would have to update this
text every time the versions change. However I have a script that
updates the library versions before a release of my AI so I
should always be using the latest versions at the time of release.


Features
--------
Building airports and managing airport routes connecting two airports.
Saving and loading are supported.
Aircraft maximum distance supported.
Handling of reaching maximum allowed aircraft.
Handling of breakdown setting and selling of old aircraft.
Handling of airport upgrading.
Building of headquarters and statues.


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
   aircraft. HeadQuarters will only be built if the speed is normal or
   fast. Statues will only be built if the speed is fast.

3. The minimum size of towns to be considered for getting an airport.
   [default depends on AI competitor speed setting]
   This setting tells WormAI the smallest town (population) where it
   is allowed to build an airport. You may want to change this
   depending on the startdate you use.

4. The minimum distance between airports.
   [default depends on AI competitor speed setting]
   This setting tells WormAI the minimum allowed distance between airports
   to build a route. You may want to change this depending on your map size.

5. The maximum distance between airports.
   [default depends on AI competitor speed setting]
   This setting tells WormAI the maximum allowed distance between airports
   to build a route. You may want to change this depending on your map size.


Limitations and shortcomings
----------------------------
Currently only supports aircraft and only transports pax.
It doesn't do very well when infrastructure maintenance is on.
Every route consists of 2 airports, unconnected to other airports.
Only well tested in temperate climate. Performance in arctic is
not as good but overall not too bad. In sub-tropic it doesn't do
very well since it only transports passengers but not water or food.
Doesn't start building as fast as some other AI's meaning that
in situations with a limited amount of suitable spots for airports
it might have a difficult time starting.


Wormnest (Jacob Boerema), 2013-2016
