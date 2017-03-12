"""
The purpose of this module is to check the results of backprop in KAG against an actual neural net libary.
"""
import numpy as np
import random
from scipy import array
from pybrain import LinearLayer
from pybrain.tools.shortcuts import buildNetwork
from pybrain.structure import FeedForwardNetwork, LinearLayer, FullConnection
from pybrain.structure.modules.neuronlayer import NeuronLayer
from pybrain.structure.modules.sigmoidlayer import SigmoidLayer
from pybrain.supervised.trainers.backprop import BackpropTrainer
from pybrain.datasets.supervised import SupervisedDataSet
from irisdataset import IRIS_TEST_SET, IRIS_TRAIN_SET

# Because the version of pybrain from pip isn't up to date
class ReluLayer(NeuronLayer):
    """ Layer of rectified linear units (relu). """

    def _forwardImplementation(self, inbuf, outbuf):
        outbuf[:] = inbuf * (inbuf > 0)

    def _backwardImplementation(self, outerr, inerr, outbuf, inbuf):
        inerr[:] = outerr * (inbuf > 0)

net = FeedForwardNetwork()

inLayer = LinearLayer(4, name="in")
hidden0 = SigmoidLayer(5, name="hidden0")
#hidden1 = SigmoidLayer(5, name="hidden1")
outLayer = SigmoidLayer(3, name="out")

net.addInputModule(inLayer)
net.addModule(hidden0)
#net.addModule(hidden1)
net.addOutputModule(outLayer)

def init_params(conn):
    for i in range(len(conn.params)):
        conn.params[i] = random.uniform(-0.2, 0.2)

in2Hidden = FullConnection(inLayer, hidden0)
#hidden01 = FullConnection(hidden0, hidden1)
hidden2Out = FullConnection(hidden0, outLayer)
init_params(in2Hidden)
#set_params_to_1(hidden01)
init_params(hidden2Out)

net.addConnection(in2Hidden)
#net.addConnection(hidden01)
net.addConnection(hidden2Out)

net.sortModules()

def print_net():
    print(net)
    print("in2Hidden params")
    for (i, row) in enumerate(np.reshape(in2Hidden.params, (5, 4))):
        for (j, elem) in enumerate(row):
            print ("Input {0} == {1} ==> Output {2}".format(-j-1, elem, i+4))
    #print("hidden01 params", hidden01.params)
    print("hidden2Out params", hidden2Out.params)

print("PRE TRAINING")
print_net()

print("TRAINING")

def squashIrisSpecies(species):
    return 1/float(species) - 0.167

dataset = SupervisedDataSet(4, 3)
for datum in IRIS_TRAIN_SET:
    species = datum[-1]
    if species == 1:
        ideals = [1,0,0]
    elif species == 2:
        ideals = [0,1,0]
    elif species == 3:
        ideals = [0,0,1]
    dataset.addSample(datum[:-1], ideals)

trainer = BackpropTrainer(net, dataset=dataset, learningrate=0.01, verbose=True)

for i in range(1000):
    error = trainer.train()
    if i % 20 == 0:
        print("Iteration {0} error {1}".format(i, error))

print("POST TRAINING")
print_net()
for test in IRIS_TEST_SET:
    inputs = test[:-1]
    species = test[-1]
    print(test, net.activate(inputs))