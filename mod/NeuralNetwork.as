#include "Logging.as";
#include "KnightCommon.as";
#include "Knocked.as";
#include "SkynetConfig.as";


// Represents a single neuron in the network
class Neuron {
    Synapse[] incoming; // list of synapses which have this neuron as their 'out'
    float value = 0.0;
}

// Connection between neurons
class Synapse {
    u32 into = 0; // the index in the network neurons array of the neuron supplying the input
    u32 out = 0;  // the index in the network neurons array of the neuron receiving the output
    float weight = 0.0;
}

// A collection of neurons
class NeuralNetwork {
    Neuron[] neurons; // stored in order [inputs, hidden, outputs]
    Synapse[] synapses;
    int firstOutputIndex; // index in neurons of the first output neuron

    NetworkOutputs evaluate(NetworkInputs input) {
        float[] inputVec = input.vectorize();
        NetworkOutputs result;
        log("NeuralNetwork#evaluate", "Called. " +
                "neurons.length() = " + neurons.length() +
                ", synapses.length() = " + synapses.length() +
                ", firstOutputIndex = " + firstOutputIndex +
                ", inputVec.length() = " + inputVec.length()
                );

        if (neurons.length() < inputVec.length()) {
            log("NeuralNetwork#evaluate", "Not enough neurons for inputs!");
            return result;
        }

        log("NeuralNetwork#evaluate", "Copying inputs to input neurons.");
        for (int i=0; i < inputVec.length(); i++) {
            neurons[i].value = inputVec[i];
        }

        log("NeuralNetwork#evaluate", "Calculating neuron values.");
        for (int i=0; i < neurons.length(); i++) {
            int sum = 0;
            Neuron neuron = neurons[i];
            for (int j=0; j < neuron.incoming.length(); j++) {
                Synapse incoming = neuron.incoming[j];
                Neuron other = neurons[incoming.into];
                sum += incoming.weight * other.value;
            }

            if (neuron.incoming.length() > 0) {
                neuron.value = sigmoid(sum);
            }
        }

        log("NeuralNetwork#evaluate", "Collecting outputs.");
        float[] outputVec;
        for (int i=firstOutputIndex; i < neurons.length(); i++) {
            outputVec.push_back(neurons[i].value);
        }
        NetworkOutputs.loadFromVector(outputVec);
        return NetworkOutputs;
    }

    float sigmoid(float x) {
        return 2.0/(1.0 + Maths::Pow(CONST_E, SIGMOID_X_SCALAR * x)) - 1;
    }

    bool loadFromString(string str) {
        // loads the network from a string representation
        // returns true/false if parsing was successful
    }
}

class NetworkInputs {
    const int NUM_INPUTS = 32; // change this if inputs are changed

    int   enemyDownUp       = 0; // -1 down, 0 none, 1 up
    int   enemyLeftRight    = 0; // -1 left, 0 none, 1 right
    int   enemyAction       = 0; // 0 none, 1 action1, 2 action2
    u8    enemyKnocked      = 0;
    u8    enemyKnightState  = KnightStates::normal;
    u8    enemySwordTimer   = 0;
    u8    enemyShieldTimer  = 0;
    bool  enemyDoubleSlash  = false;
    u32   enemySlideTime    = 0;
    u32   enemyShieldDown   = 0;
    float enemyVelX         = 0.0;
    float enemyVelY         = 0.0;
    float enemyPosX         = 0.0; // might want to remove this if we move away from FlatMap
    float enemyPosY         = 0.0; // might want to remove this if we move away from FlatMap
    float enemyAimX         = 0.0; // normalized aim direction
    float enemyAimY         = 0.0;

    int   selfDownUp        = 0;
    int   selfLeftRight     = 0;
    int   selfAction        = 0; // 0 none, 1 action1, 2 action2
    u8    selfKnocked       = 0;
    u8    selfKnightState   = KnightStates::normal;
    u8    selfSwordTimer    = 0;
    u8    selfShieldTimer   = 0;
    bool  selfDoubleSlash   = false;
    u32   selfSlideTime     = 0;
    u32   selfShieldDown    = 0;
    float selfVelX          = 0.0;
    float selfVelY          = 0.0;
    float selfPosX          = 0.0;
    float selfPosY          = 0.0;
    float selfAimX          = 0.0;
    float selfAimY          = 0.0;

    float[] vectorize() {
        float[] result;

        result.push_back( (float)enemyDownUp      );
        result.push_back( (float)enemyLeftRight   );
        result.push_back( (float)enemyAction      );
        result.push_back( (float)enemyKnocked     );
        result.push_back( (float)enemyKnightState );
        result.push_back( (float)enemySwordTimer  );
        result.push_back( (float)enemyShieldTimer );
        result.push_back( (float)enemyDoubleSlash );
        result.push_back( (float)enemySlideTime   );
        result.push_back( (float)enemyShieldDown  );
        result.push_back( enemyVelX );
        result.push_back( enemyVelY );
        result.push_back( enemyPosX );
        result.push_back( enemyPosY );
        result.push_back( enemyAimX );
        result.push_back( enemyAimY );

        result.push_back( (float)selfDownUp      );
        result.push_back( (float)selfLeftRight   );
        result.push_back( (float)selfAction      );
        result.push_back( (float)selfKnocked     );
        result.push_back( (float)selfKnightState );
        result.push_back( (float)selfSwordTimer  );
        result.push_back( (float)selfShieldTimer );
        result.push_back( (float)selfDoubleSlash );
        result.push_back( (float)selfSlideTime   );
        result.push_back( (float)selfShieldDown  );
        result.push_back( selfVelX );
        result.push_back( selfVelY );
        result.push_back( selfPosX );
        result.push_back( selfPosY );
        result.push_back( selfAimX );
        result.push_back( selfAimY );

        if (result.length() != NUM_INPUTS) {
            log("NetworkInputs#vectorize", "ERROR: result.length != NUM_INPUTS. " + result.length + ", " + NUM_INPUTS);
        }

        return result;
    }

    void loadFromBlobs(CBlob@ self, CBlob@ enemy) {
        if (self.getName() != "knight" || enemy.getName() != "knight") {
            log("NetworkInputs#loadFromBlobs", "ERROR: one of the given blobs is not a knight");
            return;
        }

        KnightInfo@ selfInfo;
        if (!self.get("knightInfo", @selfInfo))
        {
            log("NetworkInputs#loadFromBlobs", "ERROR: self has no knightInfo");
            return;
        }

        KnightInfo@ enemyInfo;
        if (!enemy.get("knightInfo", @enemyInfo))
        {
            log("NetworkInputs#loadFromBlobs", "ERROR: enemy has no knightInfo");
            return;
        }

        // Enemy
        if (enemy.isKeyPressed(key_down)) {
            enemyDownUp = -1;
        }
        else if (enemy.isKeyPressed(key_up)) {
            enemyDownUp = 1;
        }

        if (enemy.isKeyPressed(key_left)) {
            enemyLeftRight = -1;
        }
        else if (enemy.isKeyPressed(key_right)) {
            enemyLeftRight = 1;
        }

        if (enemy.isKeyPressed(key_action1)) {
            enemyAction = 1;
        }
        else if (enemy.isKeyPressed(key_action2)) {
            enemyAction = 2;
        }

        enemyKnocked = getKnocked(enemy);
        enemyKnightState = enemyInfo.state;
        enemySwordTimer = enemyInfo.swordTimer;
        enemyShieldTimer = enemyInfo.shieldTimer;
        enemyDoubleSlash = enemyInfo.doubleslash;
        enemySlideTime = enemyInfo.slideTime;
        enemyShieldDown = enemyInfo.shield_down;
        enemyVelX = enemy.getVelocity().x;
        enemyVelY = enemy.getVelocity().y;
        enemyPosX = enemy.getPosition().x;
        enemyPosY = enemy.getPosition().y;

        Vec2f enemyAimDir;
        enemy.getAimDirection(enemyAimDir);
        enemyAimX = enemyAimDir.x;
        enemyAimY = enemyAimDir.y;


        // Self
        if (self.isKeyPressed(key_down)) {
            selfDownUp = -1;
        }
        else if (self.isKeyPressed(key_up)) {
            selfDownUp = 1;
        }

        if (self.isKeyPressed(key_left)) {
            selfLeftRight = -1;
        }
        else if (self.isKeyPressed(key_right)) {
            selfLeftRight = 1;
        }

        if (self.isKeyPressed(key_action1)) {
            selfAction = 1;
        }
        else if (self.isKeyPressed(key_action2)) {
            selfAction = 2;
        }

        selfKnocked = getKnocked(self);
        selfKnightState = selfInfo.state;
        selfSwordTimer = selfInfo.swordTimer;
        selfShieldTimer = selfInfo.shieldTimer;
        selfDoubleSlash = selfInfo.doubleslash;
        selfSlideTime = selfInfo.slideTime;
        selfShieldDown = selfInfo.shield_down;
        selfVelX = self.getVelocity().x;
        selfVelY = self.getVelocity().y;
        selfPosX = self.getPosition().x;
        selfPosY = self.getPosition().y;

        Vec2f selfAimDir;
        self.getAimDirection(selfAimDir);
        selfAimX = selfAimDir.x;
        selfAimY = selfAimDir.y;
    }
}

class NetworkOutputs {
    const int NUM_OUTPUTS = 6;

    bool down       = false;
    bool up         = false;
    bool left       = false;
    bool right      = false;
    bool action1    = false;
    bool action2    = false;

    void loadFromVector(float[] vector) {
        if (vector.length() != NUM_OUTPUTS) {
            log("NetworkOutputs#loadFromVector", "ERROR: incorrect vector size " + vector.length());
            return;
        }

        if (vector[0] > 0) down     = true;
        if (vector[1] > 0) up       = true;
        if (vector[2] > 0) left     = true;
        if (vector[3] > 0) right    = true;
        if (vector[4] > 0) action1  = true;
        if (vector[5] > 0) action2  = true;
    }

    void setBlobKeys(CBlob@ knight) {
        knight.setKeyPressed(key_down, down);
        knight.setKeyPressed(key_up, up);
        knight.setKeyPressed(key_left, left);
        knight.setKeyPressed(key_right, right);
        knight.setKeyPressed(key_action1, action1);
        knight.setKeyPressed(key_action2, action2);
    }
}
