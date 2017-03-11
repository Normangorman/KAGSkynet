"""
This script generates a neural network and serializes into the form that NeuralNetwork.as understands.
"""

NUM_INPUTS = 3
HIDDEN_LAYER_SIZE = 5
NUM_HIDDEN_LAYERS = 2
NUM_OUTPUTS = 4
DEFAULT_WEIGHT = 1.0

def netgen():
    net = "<network>"
    net += "{0},{1},{2}@".format(NUM_INPUTS, HIDDEN_LAYER_SIZE * NUM_HIDDEN_LAYERS, NUM_OUTPUTS)

    net += "@" # skip the responses and biases

    input_ids = range(-1, -NUM_INPUTS-1, -1)
    print("input_ids", input_ids)

    output_ids = range(0, NUM_OUTPUTS)
    print("output_ids", output_ids)

    hidden_layers = []
    for i in range(NUM_HIDDEN_LAYERS):
        first_id_in_layer = NUM_OUTPUTS + i * HIDDEN_LAYER_SIZE
        layer = range(first_id_in_layer, first_id_in_layer + HIDDEN_LAYER_SIZE)
        print("Hidden layer", i, layer)
        hidden_layers.append(layer)

    synapses = [] # list of tuples
    def add(a, b):
        synapses.append((a,b))

    # Inputs -> h1
    for i in input_ids:
        for h in hidden_layers[0]:
            add(i, h)

    # h(n) -> h(n+1)
    for (n, layer) in enumerate(hidden_layers[:-1]): # all except the last one
        next_layer = hidden_layers[n+1]
        for h1 in layer:
            for h2 in next_layer:
                add(h1, h2)

    # final layer -> outputs
    for h in hidden_layers[-1]:
        for o in output_ids:
            add(h, o)


    net += "#".join(["{0},{1},{2}".format(a,b,DEFAULT_WEIGHT) for (a,b) in synapses])

    net += "</network>"
    return net

nets = netgen()
with open("netgen.txt", "w") as f:
    f.write(nets)
