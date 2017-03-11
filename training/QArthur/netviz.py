import pygame
import sys
import random
from pygame.locals import *

NUM_HIDDEN_LAYERS = 2
HIDDEN_LAYER_SIZE = 5
WIDTH = 1600
HEIGHT = 1000
NEURON_COLOR = (0, 0, 255)
SYNAPSE_COLOR = (0, 255, 0)
BACKGROUND_COLOR = (255,255,255)
MIN_SYNAPSE_WIDTH = 1
MAX_SYNAPSE_WIDTH = 5
FONT_SIZE = 20
SYNAPSE_LABEL_COLOR = (0, 0, 0)

class Network:
    def __init__(self):
        self.layers = []
        self.synapses = []

    def add_layer(self, list_of_ids):
        self.layers.append(list_of_ids)

    def add_synapse(self, syn):
        self.synapses.append(syn)

    def draw(self, screen, camera):
        max_layer_size = max(map(len, self.layers))
        neuron_cell_height = int(HEIGHT / float(max_layer_size))
        neuron_radius = int(neuron_cell_height * 0.4)

        startx = 10
        starty = 10
        layer_spacing = (WIDTH) / float(len(self.layers))
        neuron_positions = {} # maps id to (x,y)
        font = pygame.font.SysFont(None, FONT_SIZE)
        for (i, layer) in enumerate(self.layers):
            for (j, neuronID) in enumerate(layer):
                print("neuronID", neuronID)
                x = int(startx + i * layer_spacing)
                y = int(starty + j * neuron_cell_height)
                x = int(x*camera.get_object_scale() - camera.x)
                y = int(y*camera.get_object_scale() - camera.y)
                neuron_positions[neuronID] = (x,y)

                radius = int(neuron_radius*camera.get_object_scale())
                pygame.draw.circle(screen, NEURON_COLOR, (x,y), radius, 0)

                id_text = font.render(str(neuronID), True, BACKGROUND_COLOR)
                screen.blit(id_text, (x,y))

        max_weight = max(map(lambda s: s.weight, self.synapses))
        for syn in self.synapses:
            pos_a = neuron_positions[syn.a]
            pos_b = neuron_positions[syn.b]
            width = max(1, int(round((syn.weight / max_weight) * MAX_SYNAPSE_WIDTH)))

            pygame.draw.line(screen, SYNAPSE_COLOR, pos_a, pos_b, 1)
            weight_text = font.render(str(syn.weight), True, SYNAPSE_LABEL_COLOR)
            pos_on_line = 0.5 + random.uniform(-0.1, 0.1)

            label_x = pos_a[0] + (pos_b[0] - pos_a[0]) * pos_on_line
            label_y = pos_a[1] + (pos_b[1] - pos_a[1]) * pos_on_line
            screen.blit(weight_text, (label_x, label_y))

class Neuron:
    def __init__(self, x, y):
        self.x = x
        self.y = y

class Synapse:
    def __init__(self, a, b, weight):
        # a and b are ids
        self.a = a
        self.b = b
        self.weight = weight

def read_input_file(fp):
    # returns a neural network
    nets = ""
    with open(fp, 'r') as f:
        nets = f.read()

    if not nets.startswith("<network>") or not nets.endswith("</network>"):
        raise Exception("Invalid network")
    
    innerPart = nets.split("<")[1].split(">")[1]

    header, meta, synapses = innerPart.split("@")
    num_inputs, num_hidden, num_outputs = map(int, header.split(","))
    
    # Add layers
    net = Network()
    net.add_layer(range(-1, -num_inputs-1, -1))
    for i in range(NUM_HIDDEN_LAYERS):
        first_id_in_layer = num_outputs + i * HIDDEN_LAYER_SIZE
        layer = range(first_id_in_layer, first_id_in_layer + HIDDEN_LAYER_SIZE)
        print("Hidden layer", i, layer)
        net.add_layer(layer)
    net.add_layer(range(0, num_outputs))

    for syn in synapses.split("#"):
        if len(syn):
            #print(syn)
            bits = syn.split(",")
            a = int(bits[0])
            b = int(bits[1])
            weight = float(bits[2])
            net.add_synapse(Synapse(a,b,weight))

    return net

class Camera:
    def __init__(self):
        self.x = 0
        self.y = 0
        self.zoom = 1.0

    def get_object_scale(self):
        return 1/self.zoom

if __name__ == "__main__":
    input_file = sys.argv[1]
    net = read_input_file(input_file)
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Test")

    camera = Camera()

    def redraw():
        screen.fill(BACKGROUND_COLOR)
        net.draw(screen, camera)
        pygame.display.update()
    redraw()

    pan = 10

    while True:
        for event in pygame.event.get():
            if event.type == KEYDOWN:
                if event.key == K_KP_PLUS:
                    print("Zooming...")
                    camera.zoom -= 0.1
                    redraw()
                elif event.key == K_KP_MINUS:
                    print("Zooming out...")
                    camera.zoom += 0.1
                    redraw()
                elif event.key == K_LEFT:
                    camera.x -= pan
                    redraw()
                elif event.key == K_RIGHT:
                    camera.x += pan
                    redraw()
                elif event.key == K_DOWN:
                    camera.y += pan
                    redraw()
                elif event.key == K_UP:
                    camera.y -= pan
                    redraw()
            elif event.type == QUIT:
                pygame.quit()
                sys.exit()