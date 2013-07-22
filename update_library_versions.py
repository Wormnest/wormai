#!python

# Purpose: automatic updating of the latest library versions
# We assume we are starting in folder OpenTTD/ai/OurAI
# We assume the libraries are in folder OpenTTD/content_download/ai/library

import os
import sys
#import re

# Libraries we are using:
lib_SuperLib = "SuperLib-";
name_SuperLib = "SUPERLIB_VERSION";
ver_SuperLib = 0;

lib_AILibList = "AILibList-";
name_AILibList = "AILIBLIST_VERSION";
ver_AILibList = 0;

# ai library folder
lib_folder = os.path.abspath("../../content_download/ai/library");

# nut file to put the version numbers in
lib_versions_file = "libversions.nut";


# Get the number part of the filename
def get_number(name):
    number = name.split(".")[0].split("-")[1];
    if number.isdigit():
        return int(number);
    else:
        return -1;

# Compare with the current version and return new version if its higher
def check_version(ver, current_version):
    if ver > current_version:
        return ver;
    else:
        return current_version;


# Walk the library folder
for folder, subs, files in os.walk(lib_folder):
    for filename in files:
        # Test if a filename starts with one of our libraries names
        if filename.startswith(lib_SuperLib):
            ver = get_number(filename);
            ver_SuperLib = check_version(ver, ver_SuperLib);
        elif filename.startswith(lib_AILibList):
            ver = get_number(filename);
            ver_AILibList = check_version(ver, ver_AILibList);

print("Current SuperLib version is " + str(ver_SuperLib));
print("Current AILibList version is " + str(ver_AILibList));

# Write to file.
# WARNING: It will overwrite any old content of the file!
lib_file = open(lib_versions_file, "wt")
lib_file.write("/*\n");
lib_file.write(" * Warning: this is an automatically generated file. Do not change by hand.\n");
lib_file.write(" * Any changes you make will be lost the next time it's regenerated!\n");
lib_file.write("*/\n");
lib_file.write("\n");
lib_file.write(name_SuperLib + " <- " + str(ver_SuperLib) + ";\n");
lib_file.write(name_AILibList + " <- " + str(ver_AILibList) + ";\n");
lib_file.close();
