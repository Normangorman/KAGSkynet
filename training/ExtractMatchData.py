from bs4 import BeautifulSoup
import os
import math
from NetworkStructs import KnightInputs, NetworkInputs, NetworkOutputs, extractMatchData

TRAIN_DIR = "data/DeynardeEluded17_02_2017/clean/train"
TEST_DIR = "data/DeynardeEluded17_02_2017/clean/test"
TRAIN_OUTPUT_F = "data/DeynardeEluded17_02_2017/clean/nn_train_data.txt"
TEST_OUTPUT_F = "data/DeynardeEluded17_02_2017/clean/nn_test_data.txt"

def createDataFile(match_directory, output_f):
    matches = []
    for filePath in os.listdir(match_directory):
        with open(match_directory + "/" + filePath, 'r') as f:
            print(filePath)
            soup = BeautifulSoup(f.read())
            matches.append(extractMatchData(soup))

    with open(output_f, 'w') as f:
        for match in matches:
            for (inputs, outputs) in match:
                inputs_s = ",".join([str(inp) for inp in inputs.toVector()])
                outputs_s = ",".join([str(out) for out in outputs.toVector()])
                f.write(inputs_s + "|" + outputs_s + "\n")
            f.write("#\n") # the # symbol separates matches

createDataFile(TRAIN_DIR, TRAIN_OUTPUT_F)
createDataFile(TEST_DIR, TEST_OUTPUT_F)
