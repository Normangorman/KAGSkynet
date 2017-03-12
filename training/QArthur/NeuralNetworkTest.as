#define SERVER_ONLY
#include "NeuralNetwork.as"
#include "ArthurConfig.as"
#include "Logging.as"

void testSynapse(NeuralNetwork@ net, int fromID, int toID, float expectedWeight) {
    log("testSynapse", "Testing " + fromID + "->" + toID);
    Neuron@ toNeuron = net.getNeuron(toID);
    
    bool found = false;
    for (int i=0; i < toNeuron.incoming.length(); ++i) {
        Synapse@ syn = toNeuron.incoming[i];
        if (syn.fromNeuron == fromID) {
            //log("testSynapse", "Weight " + syn.weight);
            found = true;
            if (!almostEqual(syn.weight, expectedWeight)) {
                log("testSynapse", "Wrong weight for " + fromID + "->" + toID
                            + ". Expected " + strFloat(expectedWeight)
                            + ", got " + strFloat(syn.weight)
                            );
            }
        }
    }

    if (!found) {
        exception("testSynapse", "Synapse not found!");
    }
}

void testNetwork1() {
    NeuralNetwork net();
    net.loadFromString(BACKPROP_TEST_NETWORK);
    // This same network was evaluated in Pybrain to see what all the parameters *should be*. See netcheck.py
    // These tests compare the parameters in KAG to the expected ones
    // The values assume a learning rate of 0.1 and a sigmoid network

    float[] inputVec = {1, 2};
    float[] idealVec = {4};

    // Test forward pass
    float[] outputVec = net.forward(inputVec);
    if (!almostEqual(outputVec[0], 0.8704731)) {
        log("runTests", "FAIL Forward pass" + outputVec[0]);
    }


    // Test backprop
    float totalError = net.train(inputVec, idealVec);
    /*
    for (int i=0; i < net.orderedNeurons.length(); i++) {
        Neuron@ n = net.orderedNeurons[i];
        log("runTests", "Neuron " + n.id);
    }
    */
    if (!almostEqual(totalError, 4.89696931658)) {
        log("runTests", "FAIL totalError " + totalError);
    }

    int[] synapseFroms;
    int[] synapseTos;
    float[] expectedSynapseWeights;
    synapseFroms.push_back(-1);
    synapseTos.push_back(1);
    expectedSynapseWeights.push_back(1.00159407);

    synapseFroms.push_back(-1);
    synapseTos.push_back(2);
    expectedSynapseWeights.push_back(1.00159407);

    synapseFroms.push_back(-2);
    synapseTos.push_back(1);
    expectedSynapseWeights.push_back(1.00318815);

    synapseFroms.push_back(-2);
    synapseTos.push_back(2);
    expectedSynapseWeights.push_back(1.00318815);

    synapseFroms.push_back(1);
    synapseTos.push_back(0);
    expectedSynapseWeights.push_back(1.03361188);

    synapseFroms.push_back(2);
    synapseTos.push_back(0);
    expectedSynapseWeights.push_back(1.03361188);

    for (int i=0; i < synapseFroms.length(); i++) {
        int from = synapseFroms[i];
        int to = synapseTos[i];
        float expectedWeight = expectedSynapseWeights[i];
        testSynapse(@net, from, to, expectedWeight);
    }
}

void testNetwork2() {
    NeuralNetwork net();
    net.loadFromString(BACKPROP_TEST_NETWORK2);

    float[] inputVec = {1, 2, 3};
    float[] idealVec = {5, 6, 7, 8};

    // Test forward pass
    float[] outputVec = net.forward(inputVec);
    for (int i=0; i < outputVec.length(); i++) {
        if (!almostEqual(outputVec[i], 0.99307812)) {
            log("testNetwork2", "FAIL Forward pass " + i + " " + outputVec[i]);
        }
    }

    // Test backprop
    float totalError = net.train(inputVec, idealVec);
    if (!almostEqual(totalError, 63.152376)) {
        log("runTests", "FAIL totalError " + totalError);
    }

    int[] synapseFroms;
    int[] synapseTos;
    float[] expectedSynapseWeights;
    // Only test some of the weights
    synapseFroms.push_back(-1);
    synapseTos.push_back(4);
    expectedSynapseWeights.push_back(1.00000125667);

    synapseFroms.push_back(-1);
    synapseTos.push_back(5);
    expectedSynapseWeights.push_back(1.00000125667);

    synapseFroms.push_back(-1);
    synapseTos.push_back(6);
    expectedSynapseWeights.push_back(1.00000125667);

    synapseFroms.push_back(-1);
    synapseTos.push_back(7);
    expectedSynapseWeights.push_back(1.00000125667);

    synapseFroms.push_back(-1);
    synapseTos.push_back(8);
    expectedSynapseWeights.push_back(1.00000125667);

    synapseFroms.push_back(-2);
    synapseTos.push_back(4);
    expectedSynapseWeights.push_back(1.00000251334);

    synapseFroms.push_back(-2);
    synapseTos.push_back(5);
    expectedSynapseWeights.push_back(1.00000251334);

    synapseFroms.push_back(-2);
    synapseTos.push_back(6);
    expectedSynapseWeights.push_back(1.00000251334);

    synapseFroms.push_back(-2);
    synapseTos.push_back(7);
    expectedSynapseWeights.push_back(1.00000251334);

    synapseFroms.push_back(-2);
    synapseTos.push_back(8);
    expectedSynapseWeights.push_back(1.00000251334);

    synapseFroms.push_back(-3);
    synapseTos.push_back(4);
    expectedSynapseWeights.push_back(1.00000377);

    synapseFroms.push_back(-3);
    synapseTos.push_back(5);
    expectedSynapseWeights.push_back(1.00000377);

    synapseFroms.push_back(-3);
    synapseTos.push_back(6);
    expectedSynapseWeights.push_back(1.00000377);

    synapseFroms.push_back(-3);
    synapseTos.push_back(7);
    expectedSynapseWeights.push_back(1.00000377);

    synapseFroms.push_back(-3);
    synapseTos.push_back(8);
    expectedSynapseWeights.push_back(1.00000377);

    // Hidden 0 -> 1
    synapseFroms.push_back(4);
    synapseTos.push_back(9);
    expectedSynapseWeights.push_back(1.00010165);

    synapseFroms.push_back(4);
    synapseTos.push_back(10);
    expectedSynapseWeights.push_back(1.00010165);

    // Hidden 1 -> output
    synapseFroms.push_back(9);
    synapseTos.push_back(0);
    expectedSynapseWeights.push_back(1.00273568);

    synapseFroms.push_back(9);
    synapseTos.push_back(1);
    expectedSynapseWeights.push_back(1.00341842);

    for (int i=0; i < synapseFroms.length(); i++) {
        int from = synapseFroms[i];
        int to = synapseTos[i];
        float expectedWeight = expectedSynapseWeights[i];
        testSynapse(@net, from, to, expectedWeight);
    }
}


void testIrisNetwork() {
    log("testIrisNetwork", "Called");
    NeuralNetwork net();
    net.loadFromString(IRIS_NETWORK_RAND_WEIGHTS);

    int trainIterations = 1000;
    for (int i=0; i < trainIterations; i++) {
        float totalError = 0.0;
        for (int k=0; k < IRIS_TRAIN_SET.length(); k++) {
            //int randomIndex = XORRandom(IRIS_TRAIN_SET.length);
            int randomIndex = k;
            float[] randomDatum = IRIS_TRAIN_SET[randomIndex];
            //log("testIrisNetwork", "randomIndex " + randomIndex);
            if (randomDatum.length == 0) {
                log("testIrisNetwork", "ERROR randomDatum length is 0");
                continue;
            }

            float[] inputs;
            float[] ideals;
            for (int j=0; j < 4; j++) {
                inputs.push_back(randomDatum[j]);
            }

            // Species is 1, 2, or 3 in the data set
            // But the activation function is a sigmoid, so these values are squashed into the ranges 0.0->0.33, 0.33->0.66, 0.66->1
            float species = randomDatum[4];
            if (species == 1) {
                ideals.push_back(1);
                ideals.push_back(0);
                ideals.push_back(0);
            }
            else if (species == 2) {
                ideals.push_back(0);
                ideals.push_back(1);
                ideals.push_back(0);
            }
            else if (species == 3) {
                ideals.push_back(0);
                ideals.push_back(0);
                ideals.push_back(1);
            }

            float output = net.forward(inputs)[0];
            float error = net.train(inputs, ideals);
            totalError += error;
        }

        log("testIrisNetwork", "Epoch " + i + " total error " + totalError);
    }

    log("testIrisNetwork", "Final weights:");
    for (int i=0; i < net.orderedNeurons.length(); i++) {
        Neuron@ n = net.orderedNeurons[i];
        for (int j=0; j < n.incoming.length(); j++) {
            Synapse@ s = n.incoming[j];
            log("testIrisNetwork", s.fromNeuron + " == " + s.weight + " ==> " + s.toNeuron);
        }
    }

    // Evaluate on test set
    float testSetAccuracy = 0.0;
    for (int i=0; i < IRIS_TEST_SET.length(); i++) {
        float[] datum = IRIS_TEST_SET[i];
        if (datum.length() == 0) {
            log("testIrisNetwork", "ERROR test datum length is 0");
            continue;
        }

        float[] inputs;
        for (int j=0; j < 4; j++) {
            inputs.push_back(datum[j]);
        }
        float actualSpecies = datum[4];

        float[] result = net.forward(inputs);
        int predictedSpecies = argmax(result) + 1;
        log("testIrisNetwork", "index " + i + ", actual " + actualSpecies
            + ", predicted " + predictedSpecies
            + ", result " + result[0] + "," + result[1] + "," + result[2]);

        if (predictedSpecies == actualSpecies) {
            testSetAccuracy += 1 / float(IRIS_TEST_SET.length);
        }
    }

    print("Test set accuracy " + testSetAccuracy);
}

float squashIrisSpecies(float species) {
    return species/3.0 - 0.167;
}

float unsquashIrisSpecies(float squashed) {
    if (squashed < 0.33) {
        return 1;
    }
    else if (squashed < 0.66) {
        return 2;
    }
    else {
        return 3;
    }
}

void runTests() {
    log("runTests", "RUNNING TESTS");
    testNetwork1();
    testNetwork2();
    testIrisNetwork();
    log("runTests", "FINISHED");
}

void onInit(CRules@ this) {
    runTests();
}

void onReload(CRules@ this) {
    runTests();
}

bool almostEqual(float x, float y, float epsilon=0.000001) {
    return Maths::Abs(x - y) < epsilon;
}

// Returns a high precision string (to 12 d.p.)
string strFloat(float x) {
    return formatFloat(x, "", 0, 12);
}

float argmax(float[] xs) {
    int maxIndex = 0;
    float maxVal = -99999999999999;

    for (int i=0; i < xs.length(); ++i) {
        if (xs[i] > maxVal) {
            maxIndex = i;
            maxVal = xs[i];
        }
    }

    return maxIndex;
}