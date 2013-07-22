#!python

import os
import re

# ----------------------------------
# Definitions:
# ----------------------------------

# AI name
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

base_dir_name = ai_pack_name + "-v" + version
temp_dir_name = "..\\temp"
dir_name =  temp_dir_name + "\\" + base_dir_name
tar_name = base_dir_name + ".tar"

# Linux commands:
#os.system("mkdir " + dir_name);
#os.system("cp -Ra *.nut lang " + dir_name);
#os.system("tar -cf " + tar_name + " " + dir_name);
#os.system("rm -r " + dir_name);

# Windows
# Copies all files and non empty folders except the files/folders excluded in exclude.exc
os.system("xcopy *.* " + dir_name + "\\ /S /EXCLUDE:exclude.exc");

# Now tar the folder we just made
# Since cd doesn't seem to work here we will do it in a batch file
os.system("run_tar.bat " + tar_name + " " + base_dir_name)

# Now copy it to our WormAI\releases folder...
os.system("xcopy " + temp_dir_name + "\\" + tar_name + " releases\\");
os.system("del " + temp_dir_name + "\\" + tar_name)
