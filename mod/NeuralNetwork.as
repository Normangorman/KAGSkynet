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
    u32 intoNeuron = 0; // the index in the network neurons array of the neuron supplying the input
    u32 outNeuron  = 0;  // the index in the network neurons array of the neuron receiving the output
    float weight   = 0.0;
}

// A collection of neurons
class NeuralNetwork {
    Neuron[] neurons; // stored in order [inputs, hidden, outputs]
    bool loggedOnce = true;

    NetworkOutputs evaluate(NetworkInputs input) {
        //log("evaluate", "Called. loggedOnce = " + loggedOnce);
        float[] inputVec = input.vectorize();
        string inputVecDebug;
        for (int i=0; i < inputVec.length(); i++) {
            inputVecDebug += inputVec[i] + ", ";
        }
        NetworkOutputs result;
        if (!loggedOnce) {
            log("NeuralNetwork#evaluate", "Called. " +
                    "neurons.length() = " + neurons.length() +
                    ", inputVec.length() = " + inputVec.length() +
                    ", inputVec = " + inputVecDebug
                    );
        }

        if (neurons.length() < inputVec.length()) {
            log("NeuralNetwork#evaluate", "ERROR Not enough neurons for inputs!");
            return result;
        }

        //log("NeuralNetwork#evaluate", "Copying inputs to input neurons.");
        for (int i=0; i < inputVec.length(); i++) {
            neurons[i].value = inputVec[i];
        }

        //log("NeuralNetwork#evaluate", "Calculating neuron values.");
        for (int i=0; i < neurons.length(); i++) {
            float sum = 0.0;
            Neuron@ neuron = neurons[i];
            for (int j=0; j < neuron.incoming.length(); j++) {
                Synapse@ incoming = neuron.incoming[j];
                Neuron@ other = neurons[incoming.intoNeuron];
                if (!loggedOnce)
                    log("NeuralNetwork#evaluate", incoming.intoNeuron + "("+other.value+")" +
                        " ==" + incoming.weight + "==> " + i);
                sum += incoming.weight * other.value;
            }


            if (neuron.incoming.length() > 0) {
                neuron.value = sigmoid(sum);
                if (!loggedOnce)
                    log("NeuralNetwork#evaluate", "Set value to " + neuron.value);
            }
        }

        //log("NeuralNetwork#evaluate", "Collecting outputs.");
        // The outputs are all at the end of the array
        float[] outputVec;
        string outputDebug = "";
        for (int i=neurons.length() - NUM_OUTPUTS; i < neurons.length(); i++) {
            outputDebug += neurons[i].value + ", ";
            outputVec.push_back(neurons[i].value);
        }
        result.loadFromVector(outputVec);
        if (!loggedOnce) {
            log("NeuralNetwork#evaluate", "Output vector: " + outputDebug);
            result.debug();
        }
        loggedOnce = true;
        return result;
    }

    float sigmoid(float x) {
        float result = 2.0/(1.0 + Maths::Pow(CONST_E, SIGMOID_X_SCALAR * x)) - 1;
        if (!loggedOnce) {
            log("sigmoid", "Called for " + x + ", result = " + result);
        }
        return result;
    }

    bool loadFromString(string str) {
        // loads the network from a string representation
        // returns true/false if parsing was successful
        // representation looks like:
        // <network>1,2,0.56#3,4,0.8|3,8,0.95</network>
        // | separates neurons
        // # separates synapses
        //log("loadFromString", "Loading from: " + str);
        
        // Check if valid
        if (!stringCheck(str, 0, "<network>")) {
            log("loadFromString", "ERROR str doesn't start with <network>.");
            return false;
        }
        else if (!stringCheck(str, str.length() - "</network>".length(), "</network>")) {
            log("loadFromString", "ERROR str doesn't end with </network>.");
            return false;
        }
        else {
            //log("loadFromString", "Yay str is valid");
        }

        string inner = str.substr("<network>".length(),
                str.length() - "<network>".length() - "</network>".length());
        /*
        log("loadFromString", "inner = " + inner +
                ", inner.length = " + inner.length()
                );
                */

        string[]@ neuronStrings = inner.split("|");
        //log("loadFromString", "Num neuronStrings = " + neuronStrings.length());

        for (int i=0; i < neuronStrings.length(); i++) {
            neurons.push_back(parseNeuron(neuronStrings[i]));
        }

        log("loadFromString", "Parsing finished!");
        bool valid = validate();
        return valid;
    }

    bool stringCheck(string str, int i, string sub) {
        // Returns true/false if the given string contains a substring 'sub' starting at index i
        if (str.length() < sub.length()) {
            log("stringCheck", "WARN str.length < sub.length");
            return false;
        }

        string strSub = str.substr(i, sub.length());
        /*
        log("stringCheck", "i = " + i +
                ", str.length = " + str.length() + 
                ", sub = " + sub + 
                ", i+sub.length = " + i + sub.length() + 
                ", strSub = " + strSub 
                );
                */
        return strSub == sub;
    }

    Neuron parseNeuron(string neuronStr) {
        Neuron neuron();

        if (neuronStr != "") {
            //log("parseNeuron", "Called for: " + neuronStr);
            string[]@ genes = neuronStr.split("#");
            //log("parseNeuron", "Num genes = " + genes.length());

            for (int i=0; i < genes.length(); i++) {
                string geneStr = genes[i];
                string[]@ geneParts = geneStr.split(",");
                //log("parseNeuron", "geneStr = " + geneStr);
                if (geneParts.length() != 3) {
                    log("parseNeuron", "ERROR: invalid number of geneParts " + geneParts.length());
                }
                else {
                    Synapse synapse();
                    synapse.intoNeuron = parseInt(geneParts[0]);
                    synapse.outNeuron = parseInt(geneParts[1]);
                    synapse.weight = parseFloat(geneParts[2]);
                    neuron.incoming.push_back(synapse);
                }
            }
        }

        return neuron;
    }

    bool validate() {
        // Error checks the structure of the network
        log("validate", "Validating network...");
        int n = neurons.length();
        if (n < NUM_INPUTS + NUM_OUTPUTS) {
            log("validate", "ERROR network is too small.");
            return false;
        }

        int synapseCount = 0;
        for (int i=0; i < n; i++) {
            Neuron neuron = neurons[i];

            for (int j=0; j < neuron.incoming.length(); j++) {
                Synapse s = neuron.incoming[j];
                synapseCount++;
                if (s.intoNeuron < 0 || s.intoNeuron >= n) {
                    log("validate", "ERROR invalid synapse found (intoNeuron)");
                    return false;
                }
                else if (s.outNeuron < 0 || s.outNeuron >= n) {
                    log("validate", "ERROR invalid synapse found (outNeuron)");
                    return false;
                }
            }
        }

        log("validate", "Network is valid! Neurons: " + n + 
                ", Synapses: " + synapseCount);

        return true;
    }
}

class NetworkInputs {
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

        result.push_back( enemyDownUp      );
        result.push_back( enemyLeftRight   );
        result.push_back( enemyAction      );
        result.push_back( enemyKnocked     );
        result.push_back( enemyKnightState );
        result.push_back( enemySwordTimer  );
        result.push_back( enemyShieldTimer );
        result.push_back( enemyDoubleSlash ? 1.0 : 0.0 );
        result.push_back( enemySlideTime   );
        result.push_back( enemyShieldDown  );
        result.push_back( enemyVelX );
        result.push_back( enemyVelY );
        result.push_back( enemyPosX );
        result.push_back( enemyPosY );
        result.push_back( enemyAimX );
        result.push_back( enemyAimY );

        result.push_back( selfDownUp      );
        result.push_back( selfLeftRight   );
        result.push_back( selfAction      );
        result.push_back( selfKnocked     );
        result.push_back( selfKnightState );
        result.push_back( selfSwordTimer  );
        result.push_back( selfShieldTimer );
        result.push_back( selfDoubleSlash ? 1.0 : 0.0 );
        result.push_back( selfSlideTime   );
        result.push_back( selfShieldDown  );
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
        enemyAimDir.Normalize();
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
        selfAimDir.Normalize();
        selfAimX = selfAimDir.x;
        selfAimY = selfAimDir.y;
    }
}

class NetworkOutputs {
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

    void debug() {
        log("NetworkOutputs#debug", "Set keys: down = " + down +
                ", up = " + up +
                ", left = " + left +
                ", right = " + right +
                ", action1 = " + action1 +
                ", action2 = " + action2);
    }

    void setBlobKeys(CBlob@ knight) {
        // Flip the state of the keys if needed
        if (knight.isKeyPressed(key_down) != down) knight.setKeyPressed(key_down, down);
        if (knight.isKeyPressed(key_up) != up) knight.setKeyPressed(key_up, up);
        if (knight.isKeyPressed(key_left) != left) knight.setKeyPressed(key_left, left);
        if (knight.isKeyPressed(key_right) != right) knight.setKeyPressed(key_right, right);
        if (knight.isKeyPressed(key_action1) != action1) knight.setKeyPressed(key_action1, action1);
        if (knight.isKeyPressed(key_action2) != action2) knight.setKeyPressed(key_action2, action2);
    }
}
