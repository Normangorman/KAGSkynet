import tensorflow as tf
from tensorflow import keras
import numpy as np
import sys
from tensorflow.keras.utils import plot_model
import pydot
import graphviz

TRAIN_FILE = 'nn_train_data.txt'
TEST_FILE = 'nn_test_data.txt'

def load_data_file(fpath):
    with open(fpath, 'r') as f:
        x_data = []
        y_data = []
        for line in f:
            if line.startswith('#') or len(line.strip()) == 0:
                continue
            else:
                state1, state2 = line.split('|')
                xs = [float(z) for z in state1.split(',')]
                #ys = [float(z) for z in state2.split(',')]
                ss = state2.split(',')
                # Just the positions
                #indices = [0,1,15,16]
                indices = [10, 25]
                ys = [float(ss[i]) for i in indices]
                # ys = [float(ss[7]), float(ss[22])] # health
                # x_data.append(np.array(xs).reshape(30,1))
                # y_data.append(np.array(ys).reshape(4,1))
                x_data.append(np.array(xs))
                y_data.append(np.array(ys))
                #y_data.append(np.array(ys).reshape(4,1))
                # print(np.array(xs).reshape(30,1))
                # sys.exit(1)
        return np.array(x_data), np.array(y_data)

def load_data():
    print("Loading data...")
    x_train, y_train = load_data_file(TRAIN_FILE)
    x_test, y_test = load_data_file(TEST_FILE)
    # print(x_test)
    # sys.exit(1)
    return (x_train, y_train), (x_test, y_test)

(x_train, y_train), (x_test, y_test) = load_data()

from sklearn import tree
clf = tree.DecisionTreeClassifier()
clf = clf.fit(x_train, y_train)

right = 0 
wrong = 0
for (y, py) in zip(y_test, clf.predict(x_test)):
    if y[0] == py[0]:
        right += 1
    else:
        wrong += 1

    if y[1] == py[1]:
        right += 1
    else:
        wrong += 1

print("Right: " + str(right))
print("Wrong: " + str(wrong))

# model = keras.models.Sequential([
#   keras.layers.Dense(30, input_dim=30, activation=tf.nn.leaky_relu),
#   keras.layers.Dense(20, activation=tf.nn.leaky_relu),
#   keras.layers.Dense(20, activation=tf.nn.leaky_relu),
#   keras.layers.Dense(2, activation=tf.nn.leaky_relu),
# ])
# plot_model(model, show_shapes=True, to_file='model.png')
# model.compile(optimizer='adam',
#               loss='mean_squared_error',
#               metrics=['accuracy'])

# print("Fitting...")
# model.fit(x_train, y_train, epochs=20)
# print(model.evaluate(x_test, y_test))
# s = 1
# print(x_test[:s])
# print(model.predict(x_test[:s]))
# print(y_test[:s])
