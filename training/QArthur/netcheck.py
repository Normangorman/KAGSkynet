"""
The purpose of this module is to check the results of backprop in KAG against an actual neural net libary.
"""
import numpy as np
from scipy import array
from pybrain import LinearLayer
from pybrain.tools.shortcuts import buildNetwork
from pybrain.structure import FeedForwardNetwork, LinearLayer, FullConnection
from pybrain.structure.modules.neuronlayer import NeuronLayer
from pybrain.structure.modules.sigmoidlayer import SigmoidLayer
from pybrain.supervised.trainers.backprop import BackpropTrainer
from pybrain.datasets.supervised import SupervisedDataSet

# Because the version of pybrain from pip isn't up to date
class ReluLayer(NeuronLayer):
    """ Layer of rectified linear units (relu). """

    def _forwardImplementation(self, inbuf, outbuf):
        outbuf[:] = inbuf * (inbuf > 0)

    def _backwardImplementation(self, outerr, inerr, outbuf, inbuf):
        inerr[:] = outerr * (inbuf > 0)

net = FeedForwardNetwork()

inLayer = LinearLayer(3, name="in")
hidden0 = SigmoidLayer(5, name="hidden0")
hidden1 = SigmoidLayer(5, name="hidden1")
outLayer = SigmoidLayer(4, name="out")

net.addInputModule(inLayer)
net.addModule(hidden0)
net.addModule(hidden1)
net.addOutputModule(outLayer)

def set_params_to_1(conn):
    for i in range(len(conn.params)):
        conn.params[i] = 1.0

in2Hidden = FullConnection(inLayer, hidden0)
hidden01 = FullConnection(hidden0, hidden1)
hidden2Out = FullConnection(hidden1, outLayer)
set_params_to_1(in2Hidden)
set_params_to_1(hidden01)
set_params_to_1(hidden2Out)

net.addConnection(in2Hidden)
net.addConnection(hidden01)
net.addConnection(hidden2Out)

net.sortModules()

def print_net():
    print(net)
    print("in2Hidden params")
    for (i, row) in enumerate(np.reshape(in2Hidden.params, (5, 3))):
        for (j, elem) in enumerate(row):
            print ("Input {0} == {1} ==> Output {2}".format(-j-1, elem, i+4))
    print("hidden01 params", hidden01.params)
    print("hidden2Out params", hidden2Out.params)

print("PRE TRAINING")
print_net()

print("FORWARD PASS")
print(net.activate([1.0, 2.0, 3.0]))

dataset = SupervisedDataSet(3, 4)
dataset.addSample([1.0, 2.0, 3.0], [5.0, 6.0, 7.0, 8.0])
trainer = BackpropTrainer(net, dataset=dataset, learningrate=0.1, verbose=True)
trainer.train()

print("POST TRAINING")
print_net()