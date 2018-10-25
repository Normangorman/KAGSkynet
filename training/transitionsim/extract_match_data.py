from bs4 import BeautifulSoup
import os
import math
from collections import namedtuple

TRAIN_DIRS = ["../data/DeynardeEluded15_02_2017/clean/train",
              "../data/DeynardeEluded17_02_2017/clean/train",
              ]
TEST_DIRS =  ["../data/DeynardeEluded15_02_2017/clean/test",
              "../data/DeynardeEluded17_02_2017/clean/test",
              ]
TRAIN_OUTPUT_F = "nn_train_data.txt"
TEST_OUTPUT_F = "nn_test_data.txt"

class KnightState:
    def __init__(self):
        self.position = None
        self.velocity = None
        self.aimpos = None
        self.keys = None
        self.health = None
        self.knocked = None
        self.knightstate = None
        self.swordtimer = None
        self.shieldtimer = None
        self.doubleslash = None
        self.slidetime = None
        self.shielddown = None

class GameState:
    def __init__(self, k1state, k2state):
        self.k1state = k1state
        self.k2state = k2state

    def dump_array(self):
        k1 = self.k1state
        k2 = self.k2state

        return [k1.position[0], k1.position[1], k1.velocity[0], k1.velocity[1], k1.aimpos[0],
                k1.aimpos[1],   k1.keys,        k1.health,      k1.knocked,     k1.knightstate,
                k1.swordtimer,  k1.shieldtimer, k1.doubleslash, k1.slidetime,   k1.shielddown,
                k2.position[0], k2.position[1], k2.velocity[0], k2.velocity[1], k2.aimpos[0],
                k2.aimpos[1],   k2.keys,        k2.health,      k2.knocked,     k2.knightstate,
                k2.swordtimer,  k2.shieldtimer, k2.doubleslash, k2.slidetime,   k2.shielddown
                ]

    def dump_string(self):
        return ','.join([str(item) for item in self.dump_array()])


def create_data_file(data_dirs, output_f):
    matches = []
    for directory in data_dirs:
        print(directory)
        for filePath in os.listdir(directory):
            print(filePath)
            with open(directory + "/" + filePath, 'r') as f:
                soup = BeautifulSoup(f.read())
                matches.append(extract_game_states(soup))

    with open(output_f, 'w') as f:
        for match in matches:
            for i in range(len(match)-1):
                state1 = match[i]
                state2 = match[i+1]
                f.write(state1.dump_string() + '|' + state2.dump_string() + '\n')
            f.write("#\n") # the # symbol separates matches


def parse_vector(vecstring):
    x,y = vecstring.split(',')
    return (float(x), float(y))


def blob_data_to_knight_state(bd):
    # Loads from a BlobData tag from a recorded match in BeautifulSoup format
    ks = KnightState()
    ks.position = parse_vector(bd.position.text)
    ks.velocity = parse_vector(bd.velocity.text)
    ks.aimpos = parse_vector(bd.aimpos.text)
    ks.keys = int(bd.keys.text)
    ks.health = float(bd.health.text)
    ks.knocked = int(bd.knocked.text)
    ks.knightstate = int(bd.knightstate.text)
    ks.swordtimer = int(bd.swordtimer.text)
    ks.shieldtimer = int(bd.shieldtimer.text)
    ks.doubleslash = 1 if bd.doubleslash.text == u'true' else -1
    ks.slidetime = int(bd.slidetime.text)
    ks.shielddown = int(bd.shielddown.text)

    return ks


def extract_game_states(soup):
    # Takes the BeautifulSoup of the match file
    # Returns [(KnightState), (KnightState)]
    knights = soup.select("matchrecording allblobmeta blobmeta")
    knight1netid = knights[0].netid.text
    knight1team = knights[0].teamnum.text
    knight2netid = knights[1].netid.text
    knight2team = knights[1].teamnum.text
    winningteam = soup.matchrecording.winningteam.text

    # ensure knight1 is always winning knight
    if winningteam == knight2team:
        knight1netid, knight2netid = knight2netid, knight1netid
        knight1team, knight2team = knight2team, knight1team

    # Arrays of KnightInputs objects representing the input on each tick
    knight1data = []
    knight2data = []

    for blobdata in soup.select("matchrecording recording tick blobdata"):
        ks = blob_data_to_knight_state(blobdata)

        if blobdata.netid.text == knight1netid:
            knight1data.append(ks)
        elif blobdata.netid.text == knight2netid:
            knight2data.append(ks)
        else:
            raise Exception("netid mismatch")

    datas = zip(knight1data, knight2data)
    states = [GameState(k1s, k2s) for k1s, k2s in datas]
    return states


create_data_file(TRAIN_DIRS, TRAIN_OUTPUT_F)
create_data_file(TEST_DIRS, TEST_OUTPUT_F)
