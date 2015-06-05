#!python

# Replace AI names with some other names
# Useful to have different names for developing and then being
# able to switch names for releases.
# Note: we assume that CreateInstance() assignment will always be
# after assignment of GetName(). If not then the value of
# CreateInstance should differ from the value of GetName().

import os
import io
import re

# ----------------------------------
# Definitions:
# ----------------------------------

# AI names
# AI Release version names
ai_name_short = "WORM"
ai_name_long  = "WormAI"
# AI Development version names
ai_dev_name_short = "WOR0"
ai_dev_name_long  = "WormAIDev"

# ----------------------------------
# The information we are changing is in info.nut
info_nut_file = "info.nut";

# We want the date to be updated before releasing the tar
# and the version number to be update after updating
# Thus we can't do it at the same time.
quoted_name = ""
replace_name = ""
name_found = False

# Open file for reading and writing (r+)
info_file = io.open(info_nut_file, "r+", newline='')   # newline='' means don't convert line endings
lines = info_file.readlines();
info_file.seek(0);

for i, line in enumerate(lines):
    # Find the lines where a text string is returned
    r = re.search('return\s+\"([a-zA-Z0-9]+)\"', line)
    if (r != None):
        quoted_name = r.group(1);
        # Check if the quoted name is one of the names we're looking for
        do_replace = True;
        if quoted_name == ai_name_short:
            replace_name = ai_dev_name_short;
        elif quoted_name == ai_name_long:
            if name_found:
                do_replace = False;
            replace_name = ai_dev_name_long;
            name_found = True;
        elif quoted_name == ai_dev_name_short:
            replace_name = ai_name_short;
        elif quoted_name == ai_dev_name_long:
            if name_found:
                do_replace = False;
            replace_name = ai_name_long;
            name_found = True;
        else:
            do_replace = False;
            replace_name = "";
        if (do_replace):
            print "Replacing: '" +  quoted_name + "' with: '" + replace_name + "'";
            line = line[:r.start(1)] + replace_name + line[r.end(1):];
    # Write the possibly changed line back to file
    info_file.write(line);

# Truncate file to current size since it may have been longer before
info_file.truncate();
# Close our file
info_file.close();
