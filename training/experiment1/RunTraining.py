from __future__ import print_function

import os
import pickle
import neat
import random
import math
#import visualize
from NetworkStructs import NetworkInputs, NetworkOutputs, loadDataSetVectors

TRAIN_F = "../data/DeynardeEluded17_02_2017/clean/nn_train_data.txt"
TRAIN_DATA = loadDataSetVectors(TRAIN_F)
random.seed(0)

runs_per_net = 500

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

# Use the NN network phenotype and the discrete actuator force function.
def eval_genome(genome, config):
    net = neat.nn.FeedForwardNetwork.create(genome, config)

    fitnesses = []

    for runs in range(runs_per_net):
        r = random.randrange(0, len(TRAIN_DATA))
        example_inputs, example_outputs = TRAIN_DATA[r]

        action = net.activate(example_inputs)
        fitness = fitness_func(action, example_outputs)
        fitnesses.append(fitness)

    # The genome's fitness is its average performance across all runs.
    return 100 * (sum(fitnesses) / len(fitnesses))


def eval_genomes(genomes, config):
    for genome_id, genome in genomes:
        genome.fitness = eval_genome(genome, config)


def run():
    # Load the config file, which is assumed to live in
    # the same directory as this script.
    local_dir = os.path.dirname(__file__)
    config_path = os.path.join(local_dir, 'experiment1neatconfig')
    config = neat.Config(neat.DefaultGenome, neat.DefaultReproduction,
                         neat.DefaultSpeciesSet, neat.DefaultStagnation,
                         config_path)

    pop = neat.Population(config)
    stats = neat.StatisticsReporter()
    pop.add_reporter(stats)
    pop.add_reporter(neat.StdOutReporter(True))

    pe = neat.ParallelEvaluator(8, eval_genome)
    winner = pop.run(pe.evaluate, 2000)

    # Save the winner.
    with open('winner-feedforward', 'wb') as f:
        pickle.dump(winner, f)

    print(winner)


    """
    visualize.plot_stats(stats, ylog=True, view=True, filename="feedforward-fitness.svg")
    visualize.plot_species(stats, view=True, filename="feedforward-speciation.svg")

    node_names = {-1: 'x', -2: 'dx', -3: 'theta', -4: 'dtheta', 0: 'control'}
    visualize.draw_net(config, winner, True, node_names=node_names)

    visualize.draw_net(config, winner, view=True, node_names=node_names,
                       filename="winner-feedforward.gv")
    visualize.draw_net(config, winner, view=True, node_names=node_names,
                       filename="winner-feedforward-enabled.gv", show_disabled=False)
    visualize.draw_net(config, winner, view=True, node_names=node_names,
                       filename="winner-feedforward-enabled-pruned.gv", show_disabled=False, prune_unused=True)
    """


if __name__ == '__main__':
    run()
