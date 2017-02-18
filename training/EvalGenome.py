import pickle
import neat
import visualize
from NetworkStructs import loadDataSetVectors, fitness_func, fitness_func2

pickle_f = "experiment1/winner-feedforward"
config_f = "experiment1/experiment1neatconfig"
out_dir = "experiment1"
test_f = "data/DeynardeEluded17_02_2017/clean/nn_test_data.txt"
create_visualization = False
create_serialization = True
report_stats = False
do_kag_comparison = False

def load_genome():
    with open(pickle_f, 'r') as f:
        genome = pickle.load(f)
        print(genome)
        return genome

def serialize(net, out_path):
    #print("INPUTS")
    #print(net.input_nodes)
    #print("OUTPUTS")
    #print(net.output_nodes)
    #print("NODE_EVALS")
    #print(net.node_evals)
    #print("VALUES")
    #print(net.values)

    # Meta part
    s = "<network>"
    s += "{0},{1}@".format(len(net.input_nodes), len(net.output_nodes), 0)

    # Node bias/response part
    nodes = winner.nodes.values()
    nodes.sort()
    node_strings = []
    for node in nodes:
        node_strings.append("{0},{1},{2}".format(node.key, node.bias, node.response))
    s += "#".join(node_strings)

    s += "@"

    # Synapse part
    connections = winner.connections.values()
    connections.sort()
    gene_strings = []
    for c in connections:
        if c.enabled:
            gene_str = "{0},{1},{2}".format(c.key[0], c.key[1], c.weight)
            print(str(c), gene_str)
            gene_strings.append(gene_str)
    s += "#".join(gene_strings)
    s += "</network>"

    with open(out_path, 'w') as f:
        f.write(s)

def testKAG(net):
    examples = []

    with open("kaginputsoutputs.txt", "r") as f:
        for line in f:
            inputs_s, outputs_s = line.split("|")
            inputs = eval(inputs_s)
            outputs = eval(outputs_s)
            examples.append((inputs, outputs))

    for (ex_in, ex_out) in examples:
        action = net.activate(ex_in)
        print("net: " + str(action))
        print("kag: " + str(ex_out))

config = neat.Config(neat.DefaultGenome, neat.DefaultReproduction,
                     neat.DefaultSpeciesSet, neat.DefaultStagnation,
                     config_f)
winner = load_genome()
net = neat.nn.FeedForwardNetwork.create(winner, config)

if do_kag_comparison:
    testKAG(net)

if report_stats:
    test_set = loadDataSetVectors(test_f)
    fitnesses = []
    for (example_inputs, example_outputs) in test_set:
        action = net.activate(example_inputs)
        f = fitness_func(action, example_outputs)
        fitnesses.append(f)
        print(f)
    print ("mean: " + str(sum(fitnesses) / len(fitnesses)))


if create_serialization:
    serialize(net, out_dir + "/winner-serialized")

if create_visualization:
    node_names = {
        -1: 'self.downUp',
        -2: 'self.leftRight',
        -3: 'self.action',
        -4: 'self.knocked',
        -5: 'self.knightstate',
        -6: 'self.swordtimer',
        -7: 'self.shieldtimer',
        -8: 'self.doubleslash',
        -9: 'self.slidetime',
        -10: 'self.velX',
        -11: 'self.velY',
        -12: 'self.posX',
        -13: 'self.posY',
        -14: 'self.aimX',
        -15: 'self.aimY',
        -16: 'enemy.downUp',
        -17: 'enemy.leftRight',
        -18: 'enemy.action',
        -19: 'enemy.knocked',
        -20: 'enemy.knightstate',
        -21: 'enemy.swordtimer',
        -22: 'enemy.shieldtimer',
        -23: 'enemy.doubleslash',
        -24: 'enemy.slidetime',
        -25: 'enemy.velX',
        -26: 'enemy.velY',
        -27: 'enemy.posX',
        -28: 'enemy.posY',
        -29: 'enemy.aimX',
        -30: 'enemy.aimY',
        0: 'down',
        1: 'up',
        2: 'left',
        3: 'right',
        4: 'action1',
        5: 'action2',
        6: 'aimX',
        7: 'aimY'
    }
    for k,v in node_names.iteritems():
        node_names[k] = v + " ({})".format(k)
    visualize.draw_net(config, winner, True, node_names=node_names)

    visualize.draw_net(config, winner, view=True, node_names=node_names,
                       filename=out_dir + "/winner-feedforward.gv")
    visualize.draw_net(config, winner, view=True, node_names=node_names,
                       filename=out_dir + "/winner-feedforward-enabled.gv", show_disabled=False)
    visualize.draw_net(config, winner, view=True, node_names=node_names,
                       filename=out_dir + "/winner-feedforward-enabled-pruned.gv", show_disabled=False, prune_unused=True)
