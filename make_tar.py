#!python

import os
import re

# ----------------------------------
# Definitions:
# ----------------------------------

# Game Script name
ai_name = "WormAI"
ai_pack_name = ai_name.replace(" ", "-")

# ----------------------------------


# Script:
version = -1
for line in open("version.nut"):

	r = re.search('SELF_VERSION\s+<-\s+([0-9]+)', line)
	if(r != None):
		version = r.group(1)

if(version == -1):
	print("Couldn't find " + ai_name + " version in info.nut!")
	exit(-1)

dir_name = ai_pack_name + "-v" + version
tar_name = dir_name + ".tar"
os.system("mkdir " + dir_name);
os.system("cp -Ra *.nut lang " + dir_name);
os.system("tar -cf " + tar_name + " " + dir_name);
os.system("rm -r " + dir_name);
