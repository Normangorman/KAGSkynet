"""
This script removes matches where more than 2 blobs occurred.
This was usually because the fighters killed each other too quickly and were respawned.
"""
from bs4 import BeautifulSoup
import os

DIR = "data/DeynardeEluded17_02_2017/all"
CLEAN_DIR = "data/DeynardeEluded17_02_2017/clean"

def checkFile(text):
    soup = BeautifulSoup(text)
    numBlobMeta = len(soup.matchrecording.allblobmeta)
    print(filePath)
    print(numBlobMeta)
    if numBlobMeta != 2:
        return False
    elif soup.matchrecording.initt.text != u'0':
        return False
    else:
        return True

cleanFiles = 0
for filePath in os.listdir(DIR):
    with open(DIR + "/" + filePath, 'r') as f:
        text = f.read()
        if checkFile(text):
            with open(CLEAN_DIR + "/match" + str(cleanFiles) + ".cfg", 'w') as g:
                g.write(text)
                cleanFiles += 1
