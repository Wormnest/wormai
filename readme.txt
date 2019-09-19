WormAI OpenTTD AI
=================

Introduction
------------
WormAI is an ai that tries to be competitive. It currently supports pax
air transport and since version 5 also train support for all cargos.
In the tests I have done it usually performs fairly well as long as
you haven't turned on infrastructure maintenance.
Please report crashes and other bugs either in the discussion topic
or the issue tracker listed below.

License: see license.txt
Discussion topic: https://www.tt-forums.net/viewtopic.php?f=65&t=67167
Bug/Issue tracker: https://github.com/Wormnest/wormai/issues
Source repository: https://github.com/Wormnest/wormai


Requirements
------------
OpenTTD 1.4 or later.
AI libraries:
+ SuperLib
+ Graph.AyStar version 6
+ AILibList
+ AILibCommon (used by AILibList).
The library versions usually should be the latest versions at the time
of release.


Features
--------
Building airports and managing airport routes connecting two airports.
Saving and loading are supported.
Aircraft maximum distance supported.
Handling of reaching maximum allowed vehicles.
Handling of breakdown setting and selling of old vehicles.
Handling of airport upgrading.
Building of headquarters and statues.
Building train routes, renew trains, change length when needed, sell
when unprofitable, electrify rail.


Settings
--------
The following settings can be used. All except the thinking speed can be
changed during the game.

1. Enable aircraft [default: on]
   This setting turns on or off aircraft building. Turning this off
   means WormAI will not do any new aircraft building nor any
   maintenance on it's airlines.

2. Enable trains [default: on]
   This setting turns on or off train building.

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
It doesn't do very well when infrastructure maintenance is on.
Every air and train route consists of 2 stations, unconnected to
other stations. That means there is no interconnected network of
stations, only point to point routes.
Only well tested in temperate climate. Performance in arctic is
not as good but overall not too bad. In sub-tropic it doesn't do
very well with airplanes since it only transports passengers but
not water or food.
Doesn't start building as fast as some other AI's meaning that
in situations with a limited amount of suitable spots for airports
and/or train stations it may have a difficult time.


Credits
-------
Air transport handling is based on WrightAI.
Rail transport handling is based on SimpleAI.


Wormnest (Jacob Boerema), 2013-2019
