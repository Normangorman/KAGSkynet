#include "Logging.as";
#include "KnightCommon.as";
#include "Knocked.as";
#include "SkynetConfig.as";

// Represents a single neuron in the network
class Neuron {
    u32 id = 0;
    float value = 0.0;
    Synapse@[] incoming; // list of synapses which have this neuron as their 'outNeuron'

    Neuron(u32 _id) {
        id = _id;
    }

    void debug() {
        log("Neuron#debug", "Neuron(id=" + id + ", value=" + value + ", #incoming=" + incoming.length() + ")");
    }
}

// Connection between neurons
class Synapse {
    u32 intoNeuron = 0; // the index in the network neurons array of the neuron supplying the input
    u32 outNeuron  = 0;  // the index in the network neurons array of the neuron receiving the output
    float weight   = 0.0;

    Synapse(u32 _intoNeuron, u32 _outNeuron, float _weight) {
        intoNeuron  = _intoNeuron;
        outNeuron   = _outNeuron;
        weight      = _weight;
    }

    void debug() {
        log("Synapse#debug", "Synapse(intoNeuron=" + intoNeuron + ", outNeuron=" + outNeuron + ", weight=" + weight + ")");
    }
}

// A collection of neurons
class NeuralNetwork {
    int numInputs = 0; // numInputs and numOutputs should match constants NUM_INPUTS and NUM_OUTPUTS. validate() will check that
    int numOutputs = 0;
    int firstOutputID = 0;
    dictionary idToNeuron; // maps neuron id's to Neuron objects
    Neuron@[] orderedNeurons; // list of neurons ordered by ID. This is initialized by bake() after all synapses added. Done for efficiency.
    bool loggedOnce = true; // if set to false then detailed log messages will be printed the first time evaluate() is called

    NetworkOutputs evaluate(NetworkInputs input) {
        float[] inputVec = input.vectorize();
        NetworkOutputs result;
        if (!loggedOnce) {
            input.debug();
            log("NeuralNetwork#evaluate", "Called");
        }

        if (inputVec.length() != numInputs) {
            log("NeuralNetwork#evaluate", "ERROR inputVec size does not match numInputs");
            return result;
        }

        //log("NeuralNetwork#evaluate", "Copying inputs to input neurons.");
        for (int i=0; i < orderedNeurons.length(); i++) {
            Neuron@ n = orderedNeurons[i];
            if (n.id <= numInputs) {
                // It's an input neuron
                // Remember first input neuron has id 1 but first input value will have index 0
                n.value = inputVec[n.id-1];
                if (!loggedOnce)
                    log("NeuralNetwork#evaluate", "Assigning input " + inputVec[n.id-1] + " to neuron " + n.id);
            }
            else {
                // We hit the end of the active input neurons
                break;
            }
        }

        //log("NeuralNetwork#evaluate", "Calculating neuron values.");
        for (int i=0; i < orderedNeurons.length(); i++) {
            Neuron@ n = orderedNeurons[i];
            //Only calculate for non-input neurons (obviously or would be wiping the input values)
            if (n.id <= numInputs) continue;

            /*
            log("NeuralNetwork#evaluate", "Evaluating " + n.id);
            n.debug();
            */

            float sum = 0.0;
            for (int j=0; j < n.incoming.length(); j++) {
                Synapse@ s = n.incoming[j];
                Neuron@ other = getNeuron(s.intoNeuron);
                /*
                if (!loggedOnce) {
                    s.debug();
                    other.debug();
                    log("NeuralNetwork#evaluate", s.intoNeuron + "("+other.value+")" +
                        " ==" + s.weight + "==> " + n.id);
                }
                */
                sum += s.weight * other.value;
            }

            n.value = sigmoid(sum);
            if (!loggedOnce)
                log("NeuralNetwork#evaluate", "Set value to " + n.value);
        }

        //log("NeuralNetwork#evaluate", "Collecting outputs.");
        float[] outputVec;
        for (int i=0; i < numOutputs; i++) { outputVec.push_back(0); }
        for (int i=orderedNeurons.length()-1; i >= 0; i--) {
            Neuron@ n = orderedNeurons[i];
            if (n.id >= firstOutputID) {
                // n is an output neuron
                outputVec[n.id - firstOutputID] = n.value;
            }
            else {
                break;
            }
        }
        result.loadFromVector(outputVec);

        if (!loggedOnce) {
            string outputDebug = "";
            for (int i=0; i < outputVec.length(); i++) {
                outputDebug += outputVec[i] + ", ";
            }
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
        // <network>numInputs,numOutputs,firstOutputID@into,out,weight#into,out,weight#...</network>
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

        // Remove surrounding <network> and </network>
        string inner = str.substr("<network>".length(),
                str.length() - "<network>".length() - "</network>".length());

        // First part is metadata about the network
        // Second part is list of synapses
        string[]@ innerParts = inner.split("@");
        if (innerParts.length() != 2) {
            log("loadFromString", "ERROR Incorrect number of innerParts: " + innerParts.length());
            return false;
        }

        // Parse metadata bit
        string[]@ metaBits = innerParts[0].split(",");
        if (metaBits.length() != 3) {
            log("loadFromString", "ERROR Incorrect number of metaBits: " + metaBits.length());
            return false;
        }
        numInputs = parseInt(metaBits[0]);
        numOutputs = parseInt(metaBits[1]);
        firstOutputID = parseInt(metaBits[2]);
        
        /*
        log("loadFromString", "numInputs = " + numInputs +
                ", numOutputs = " + numOutputs +
                ", firstOutputID = " + firstOutputID
                );
                */

        // Parse synapses bit
        string[]@ synapseStrings = innerParts[1].split("#");
        for (int i=0; i < synapseStrings.length(); i++) {
            string synapseStr = synapseStrings[i];
            string[]@ synapseBits = synapseStr.split(",");
            if (synapseBits.length() != 3) {
                log("loadFromString", "ERROR Incorrect number of synapseBits: " + synapseBits.length());
                return false;
            }
            u32 intoNeuron = parseInt(synapseBits[0]);
            u32 outNeuron = parseInt(synapseBits[1]);
            float weight = parseFloat(synapseBits[2]);
            addSynapse(intoNeuron, outNeuron, weight);
        }

        //log("loadFromString", "Parsing finished!");
        return bake() && validate();
    }

    void addSynapse(u32 intoNeuron, u32 outNeuron, float weight) {
        //log("addSynapse", "Adding " + intoNeuron + "==" + weight + "==> " + outNeuron);
        Synapse s(intoNeuron, outNeuron, weight);
        
        // Add into/out if they don't exist yet
        if (!hasNeuron(intoNeuron)) {
            Neuron n(intoNeuron);
            addNeuron(@n);
        }

        if (!hasNeuron(outNeuron)) {
            Neuron n(outNeuron);
            addNeuron(@n);
        }
        
        Neuron@ outN = getNeuron(outNeuron);
        outN.incoming.push_back(@s);
    }

    bool hasNeuron(u32 id) {
        return idToNeuron.exists(""+id);
    }

    Neuron@ getNeuron(u32 id) {
        Neuron@ n;
        bool exists = idToNeuron.get(""+id, @n);
        if (!exists) {
            return null;
        }
        else {
            return n;
        }
    }

    void addNeuron(Neuron@ neuron) {
        idToNeuron.set(""+neuron.id, @neuron);
    }

    bool bake() {
        // Final step after loading is complete
        // This sets 'orderedNeurons'
        // Returns true/false whether successful
        //log("NeuralNetwork#bake", "Baking network");
        // Sort all the IDs numerically (string ordering doesn't do that because e.g. "10001" < "2"
        string[]@ everyID = idToNeuron.getKeys();
        u32[] everyIntID;
        for (int i=0; i < everyID.length(); i++) {
            everyIntID.push_back(parseInt(everyID[i]));
        }
        everyIntID.sortAsc();

        for (int i=0; i < everyIntID.length(); i++) {
            Neuron@ neuron;
            bool check = idToNeuron.get(""+everyIntID[i], @neuron);
            if (!check) {
                log("NeuralNetwork#bake", "ERROR couldn't find neuron with id: " + everyIntID[i]);
                return false;
            }
            orderedNeurons.push_back(neuron);
        }
        //log("NeuralNetwork#bake", "Num active neurons: " + orderedNeurons.length());
        return true;
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

    bool validate() {
        // Error checks the structure of the network
        log("validate", "Validating network...");
        if (numInputs != NUM_INPUTS) {
            log("validate", "ERROR network numInputs is not right: " + numInputs);
            return false;
        }
        else if (numOutputs != NUM_OUTPUTS) {
            log("validate", "ERROR network numOutputs is not right: " + numOutputs);
            return false;
        }

        if (orderedNeurons.length() == 0) {
            log("validate", "WARN no active neurons");
        }

        if (orderedNeurons.length() != idToNeuron.getSize()) {
            log("validate", "ERROR orderedNeurons length doesn't match idToNeuron size. Probably error in bake.");
            return false;
        }

        int activeInputs = 0;
        int activeHidden = 0;
        int activeOutputs = 0;
        int synapseCount = 0;
        for (int i=0; i < orderedNeurons.length(); i++) {
            Neuron@ n = orderedNeurons[i];
            if (n.id <= numInputs)
                activeInputs++;
            else if (n.id < firstOutputID)
                activeHidden++;
            else
                activeOutputs++;

            if (n is null) {
                log("validate", "ERROR null neuron found");
                return false;
            }

            /*
            log("validate", "INFO neuron debug: id="+n.id +
                   ", incoming=" + n.incoming.length());
                   */
            for (int j=0; j < n.incoming.length(); j++) {
                synapseCount++;
                Synapse@ s = n.incoming[j];
                /*
                log("validate", "INFO synapse debug: into="+s.intoNeuron +
                        ", out="+s.outNeuron +
                        ", weight="+s.weight);
                        */
                if (s is null) {
                    log("validate", "ERROR null synapse found");
                    return false;
                }
                else if (!hasNeuron(s.intoNeuron)) {
                    log("validate", "ERROR broken synapse, intoNeuron=" + s.intoNeuron);
                    return false;
                }
                else if (!hasNeuron(s.outNeuron)) {
                    log("validate", "ERROR broken synapse, outNeuron=" + s.outNeuron);
                    return false;
                }
            }
        }

        if (synapseCount == 0) {
            log("validate", "WARN no synapses");
        }

        log("validate", "Network is valid! " +
                "Synapses: " + synapseCount +
                ", Active neurons: " + orderedNeurons.length() +
                " (inputs " + activeInputs + ")" + 
                " (hidden " + activeHidden + ")" + 
                " (outputs " + activeOutputs + ")"
                );

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
        if (enemy.wasKeyPressed(key_down)) {
            enemyDownUp = -1;
        }
        else if (enemy.wasKeyPressed(key_up)) {
            enemyDownUp = 1;
        }

        if (enemy.wasKeyPressed(key_left)) {
            enemyLeftRight = -1;
        }
        else if (enemy.wasKeyPressed(key_right)) {
            enemyLeftRight = 1;
        }

        if (enemy.wasKeyPressed(key_action1)) {
            enemyAction = 1;
        }
        else if (enemy.wasKeyPressed(key_action2)) {
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
        if (self.wasKeyPressed(key_down)) {
            selfDownUp = -1;
        }
        else if (self.wasKeyPressed(key_up)) {
            selfDownUp = 1;
        }

        if (self.wasKeyPressed(key_left)) {
            selfLeftRight = -1;
        }
        else if (self.wasKeyPressed(key_right)) {
            selfLeftRight = 1;
        }

        if (self.wasKeyPressed(key_action1)) {
            selfAction = 1;
        }
        else if (self.wasKeyPressed(key_action2)) {
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

    void debug() {
        float[] vec = vectorize();
        string vecDebug;
        for (int i=0; i < vec.length(); i++) {
            vecDebug += vec[i] + ", ";
        }
        log("NetworkInputs#debug", "Input vec: " + vecDebug);
    }
}

class NetworkOutputs {
    bool down       = false;
    bool up         = false;
    bool left       = false;
    bool right      = false;
    bool action1    = false;
    bool action2    = false;
    float aimX      = 0.0;
    float aimY      = 0.0;

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
        aimX = vector[6];
        aimY = vector[7];
    }

    void debug() {
        log("NetworkOutputs#debug", "Set keys: down = " + down +
                ", up = " + up +
                ", left = " + left +
                ", right = " + right +
                ", action1 = " + action1 +
                ", action2 = " + action2 +
                ", aimX = " + aimX +
                ", aimy = " + aimY
                );
    }

    void setBlobKeys(CBlob@ knight) {
        // Flip the state of the keys if needed
        knight.setKeyPressed(key_down, down);
        knight.setKeyPressed(key_up, up);
        knight.setKeyPressed(key_left, left);
        knight.setKeyPressed(key_right, right);
        knight.setKeyPressed(key_action1, action1);
        knight.setKeyPressed(key_action2, action2);
        knight.setAimPos(knight.getPosition() + Vec2f(aimX, aimY));
    }
}
