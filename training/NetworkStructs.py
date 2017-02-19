from bs4 import BeautifulSoup
import math
import copy
import timeit
import numpy as np
import random

NUM_KNIGHT_INPUTS = 15 # for each knight
NUM_INPUTS = 30
NUM_OUTPUTS = 8
FLATMAP_WIDTH = 40*8
FLATMAP_HEIGHT = 20*8

class KnightInputs:
    def __init__(self):
        self.downUp = None
        self.leftRight = None
        self.action = None
        self.knocked = None
        self.knightstate = None
        self.swordtimer = None
        self.shieldtimer = None
        self.doubleslash = None
        self.slidetime = None
        self.velX = None
        self.velY = None
        self.posX = None
        self.posY = None
        self.aimX = None
        self.aimY = None

    def toVector(self):
        return [self.downUp, self.leftRight, self.action, self.knocked, self.knightstate,
                self.swordtimer, self.shieldtimer, self.doubleslash, self.slidetime, self.velX, self.velY,
                self.posX, self.posY, self.aimX, self.aimY]

    def loadFromVector(self, vec):
        if len(vec) != NUM_KNIGHT_INPUTS:
            raise Exception("Wrong number of inputs")
        self.downUp = vec[0]
        self.leftRight = vec[1]
        self.action = vec[2]
        self.knocked = vec[3]
        self.knightstate = vec[4]
        self.swordtimer = vec[5]
        self.shieldtimer = vec[6]
        self.doubleslash = vec[7]
        self.slidetime = vec[8]
        self.velX = vec[9]
        self.velY = vec[10]
        self.posX = vec[11]
        self.posY = vec[12]
        self.aimX = vec[13]
        self.aimY = vec[14]

    def loadFromSoup(self, blobdata):
        # Loads from a BlobData tag from a recorded match in BeautifulSoup format
        position = blobdata.position.text
        velocity = blobdata.velocity.text
        aimpos = blobdata.aimpos.text
        keys = int(blobdata.keys.text)
        knocked = int(blobdata.knocked.text)
        knightstate = int(blobdata.knightstate.text)
        swordtimer = int(blobdata.swordtimer.text)
        shieldtimer = int(blobdata.shieldtimer.text)
        doubleslashbool = True if blobdata.doubleslash.text == u'true' else False
        slidetime = int(blobdata.slidetime.text)
        #shielddown = int(blobdata.shielddown.text)

        downUp = 0
        if isKeyPressed(keys, 'down'):
            downUp = -1
        elif isKeyPressed(keys, 'up'):
            downUp = 1

        leftRight = 0
        if isKeyPressed(keys, 'left'):
            leftRight = -1
        elif isKeyPressed(keys, 'right'):
            leftRight = 1

        action = 0
        if isKeyPressed(keys, 'action1'):
            action = 1
        elif isKeyPressed(keys, 'action2'):
            action = 2

        doubleslash = 1 if doubleslashbool else 0
        velX = float(velocity.split(",")[0])
        velY = float(velocity.split(",")[1])
        posX = float(position.split(",")[0])
        posY = float(position.split(",")[1])
        posX, posY = normalizePosition(posX, posY, FLATMAP_WIDTH, FLATMAP_HEIGHT)
        (aimX, aimY) = normalize(float(aimpos.split(",")[0]), float(aimpos.split(",")[1]))

        self.loadFromVector([downUp, leftRight, action, knocked, knightstate,
                swordtimer, shieldtimer, doubleslash, slidetime, velX, velY,
                posX, posY, aimX, aimY])
        self.check()

    def check(self):
        for x in self.toVector():
            if x == None:
                raise Exception("An element in vector is None")

    def test(self):
        print("Testing KnightInputs")
        xml = ("<blobdata><netid>682</netid><position>297.568,128.325</position><velocity>3.15626,-1.03114</velocity>" +
              "<aimpos>315.171,170.823</aimpos><keys>41</keys><health>2</health><knocked>0</knocked>" +
              "<knightstate>1</knightstate><swordtimer>0</swordtimer><shieldtimer>2</shieldtimer>" +
              "<doubleslash>false</doubleslash><slidetime>0</slidetime><shielddown>1</shielddown></blobdata>")
        soup = BeautifulSoup(xml)
        self.loadFromSoup(soup)

        normPosX, normPosY = normalizePosition(297.568, 128.325, FLATMAP_WIDTH, FLATMAP_HEIGHT)
        assert(self.posX == normPosX)
        assert(self.posY == normPosY)
        assert(self.velX == 3.15626)
        assert(self.velY == -1.03114)
        normAimX, normAimY = normalize(315.171, 170.823)
        assert(self.aimX == normAimX)
        assert(self.aimY == normAimY)
        # 41 = 101001 so up pressed, right pressed, action2 pressed
        assert(self.downUp == 1)
        assert(self.leftRight == 1)
        assert(self.action == 2)
        assert(self.knocked == 0)
        assert(self.knightstate == 1)
        assert(self.swordtimer == 0)
        assert(self.shieldtimer == 2)
        assert(self.doubleslash == 0)
        assert(self.slidetime == 0)
        print("KnightInputs tests passed")


class NetworkInputs:
    def __init__(self, enemyInputs=None, selfInputs=None):
        if not enemyInputs:
            enemyInputs = KnightInputs()
        if not selfInputs:
            selfInputs = KnightInputs()

        self.enemyKnightInputs = enemyInputs
        self.selfKnightInputs = selfInputs

    def toVector(self):
        return self.enemyKnightInputs.toVector() + self.selfKnightInputs.toVector()

    def loadFromVector(self, vec):
        if len(vec) != NUM_INPUTS:
            raise Exception("Bad input vector length " + str(len(vec)))
        enemyVec = vec[:NUM_KNIGHT_INPUTS]
        selfVec = vec[NUM_KNIGHT_INPUTS:]

        self.enemyKnightInputs.loadFromVector(enemyVec)
        self.selfKnightInputs.loadFromVector(selfVec)

    def check(self):
        self.enemyKnightInputs.check()
        self.selfKnightInputs.check()


class NetworkOutputs:
    def __init__(self):
        self.down    = None
        self.up      = None
        self.left    = None
        self.right   = None
        self.action1 = None
        self.action2 = None
        self.aimX    = None
        self.aimY    = None

    def toVector(self):
        return [self.down, self.up, self.left, self.right, self.action1, self.action2,
                self.aimX, self.aimY]

    def loadFromVector(self, vec):
        if len(vec) != NUM_OUTPUTS:
            raise Exception("Bad vec length " + len(vec))
        self.down = vec[0]
        self.up = vec[1]
        self.left = vec[2]
        self.right = vec[3]
        self.action1 = vec[4]
        self.action2 = vec[5]
        self.aimX = vec[6]
        self.aimY = vec[7]

    def loadFromInputs(self, inputs):
        # loads from a KnightInputs object
        # this is useful because the outputs for a nnet are inputs from the *next tick* in a match
        self.down    = 1 if inputs.downUp == -1 else -1
        self.up      = 1 if inputs.downUp == 1 else -1
        self.left    = 1 if inputs.leftRight == -1 else -1
        self.right   = 1 if inputs.leftRight == 1 else -1
        self.action1 = 1 if inputs.action == 1 else -1
        self.action2 = 1 if inputs.action == 2 else -1
        self.aimX = inputs.aimX
        self.aimY = inputs.aimY

    def check(self):
        for x in self.toVector():
            if x == None:
                raise Exception("An element in vector is None")


def normalize(x, y):
    # returns normalized vector
    length = math.sqrt(x**2 + y**2)
    if length == 0:
        return 0,0
    else:
        return x/length, y/length


def normalizePosition(x, y, mapWidth, mapHeight):
    # Normalizes a kag position vector
    return x/float(mapWidth), y/float(mapHeight)


def isKeyPressed(keys, key):
    # takes KAG style keys (integer) and string key name
    # returns True/False whether key is pressed
    if key == 'up':
        return keys & 1 != 0
    elif key == 'down':
        return keys & 2 != 0
    elif key == 'left':
        return keys & 4 != 0
    elif key == 'right':
        return keys & 8 != 0
    elif key == 'action1':
        return keys & 16 != 0
    elif key == 'action2':
        return keys & 32 != 0
    else:
        print("UNKNOWN KEY " + key)
        return False


def extractMatchData(soup):
    # Takes the BeautifulSoup of the match file
    # Returns a list of tuples ([NetworkInputs], [NetworkOutputs])
    # Data for the winner of the match is used as inputs
    # The loser is the outputs
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
        if blobdata.netid.text == knight1netid:
            k1 = KnightInputs()
            k1.loadFromSoup(blobdata)
            knight1data.append(k1)
        elif blobdata.netid.text == knight2netid:
            k2 = KnightInputs()
            k2.loadFromSoup(blobdata)
            knight2data.append(k2)
        else:
            raise Exception("ERROR netid mismatch")

    data = []
    for i in range(0, len(knight1data) - 1):
        if i >= len(knight2data): break
        # remember enemy data goes first
        inputs = NetworkInputs(enemyInputs=knight2data[i], selfInputs=knight1data[i])
        outputs = NetworkOutputs()
        outputs.loadFromInputs(knight1data[i+1])
        data.append((inputs, outputs))
    return data

def loadDataSet(filePath):
    # Reads the data file and returns a list of lists, where each inner list
    # is the data for one match and has the format [(inputs,outputs), (inputs, outsputs) ...]
    matches = []
    match = []
    with open(filePath, 'r') as f:
        for line in f:
            if line[0] == "#": # the # symbol is match separator
                matches.append(copy.deepcopy(match))
                match = []
            else:
                in_str, out_str = line.strip().split("|")
                in_vec = [float(x) for x in in_str.split(",")]
                out_vec = [float(x) for x in out_str.split(",")]
                #print(in_str, out_str)
                #print(in_vec, out_vec)

                inputs = NetworkInputs()
                inputs.loadFromVector(in_vec)
                outputs = NetworkOutputs()
                outputs.loadFromVector(out_vec)

                match.append((inputs, outputs))
    return matches

def loadDataSetVectors(filePath):
    matches = loadDataSet(filePath)
    vector_matches = []
    for match in matches:
        m = []
        for (inputs, outputs) in match:
            m.append((inputs.toVector(), outputs.toVector()))
        vector_matches.append(m)
    return vector_matches

def fitness_func(estimate, actual):
    # Takes 2 output vectors and compares them, returning a number between 0 and 1
    # 0 if completely different, 1 if identical
    n = len(estimate)
    sum = 0.0

    for i in range(n):
        e, a = estimate[i], actual[i]
        delta = abs(a - e) / 2.0
        sum += delta / n

    return 1 - sum

def sign(x):
    return (1,-1)[x<0]

def fitness_func2(estimate, actual):
    # Takes 2 output vectors and compares them, returning a number between 0 and 1
    # 0 if completely different, 1 if identical
    n = len(estimate)
    sum = 0.0

    for i in range(n):
        e, a = estimate[i], actual[i]
        if i <= 5: # button press
            delta = 0.0 if sign(a) == sign(e) else 1.0
        else: # aim
            delta = abs(a - e) / 2.0

        sum += delta / n

    return 1 - sum

def test_fitness_func2(data):
    for (a1,a2) in data:
        f = fitness_func2(a1, a2)

if __name__ == "__main__":
    k = KnightInputs()
    k.test()

    iterations = 1
    np_arrays = []
    reg_arrays = []
    print("Generating data")
    for i in range(iterations):
        #np_rand = np.random.rand(2,8)
        reg_rand = [random.random() for j in range(16)]
        #np_arrays.append((np_rand[0], np_rand[1]))
        reg_arrays.append((reg_rand[:8], reg_rand[8:]))


    #np_test = lambda: test_fitness_func2(np_arrays)
    reg_test = lambda: test_fitness_func2(reg_arrays)
    #print("running np_test")
    #print(timeit.timeit(np_test))
    print("running reg_test")
    #print(timeit.timeit(reg_test))
    data = [([1,2,3,4,5,6,7,8], [1,2,3,4,5,6,7,8])]
    print(timeit.timeit(lambda: fitness_func2(data[0][0], data[0][1])))


    #print(loadDataSet("TrainingData/DeynardeEluded17_02_2017/clean/nn_test_data.txt"))
