#include "Logging.as";
#include "KnightCommon.as";
#include "Knocked.as";
#include "ArthurConfig.as";

// Represents a single neuron in the network
shared class Neuron {
    int        id;
    float      value;       // value given by act_func(bias + response * sum)
    float      response;
    float      bias;
    Synapse@[] incoming;    // list of synapses which have this neuron as their 'toNeuron'
    Synapse@[] outgoing;    // list of synapses which have this neuron as their 'fromNeuron'
    float      sumIncoming; // for backprop. Sum of incoming weighted values
    float      delta;       // for backprop. Defined as (d_E/d_value) / (d_value/d_sumIncoming)
    bool       hasDelta;    // for backprop. True/false whether we have been able to compute the delta yet

    Neuron(int _id) {
        id = _id;
        value = 0.0;
        response = 1.0;
        bias = 0.0;
    }

    void computeDelta(float errWrtOut) {
        // This is where the derivative of the current activation function lives
        // Make sure to change it if the activation function changes
        // using sigmoid deriv
        delta = errWrtOut * sigmoidDeriv(sumIncoming);
    }

    void debug() {
        log("Neuron#debug", "Neuron(id=" + id + ", value=" + value + ", response=" + response + ", bias=" + bias +
                            ", #incoming=" + incoming.length() + ")");
        for (int i=0; i < incoming.length(); i++) {
            Synapse@ s = incoming[i];
            s.debug();
        }
    }
}

// Connection between neurons
shared class Synapse {
    int     fromNeuron; // the id of the neuron supplying the input
    int     toNeuron;  // the id of the neuron receiving the output
    float   weight;

    Synapse(int _fromNeuron, int _toNeuron, float _weight) {
        fromNeuron  = _fromNeuron;
        toNeuron   = _toNeuron;
        weight      = _weight;
    }

    void updateWeight(float inValue, float outDelta) {
        float dErr_dWeight = outDelta * inValue;
        weight = weight - dErr_dWeight * LEARNING_RATE;
    }

    void debug() {
        log("Synapse#debug", "   * Synapse(fromNeuron=" + fromNeuron + ", toNeuron=" + toNeuron + ", weight=" + weight + ")");
    }
}

// A collection of neurons
shared class NeuralNetwork {
    // input neurons have ids less than 0. Output neurons have ids 0 -> numOutputs, hidden neurons numOutputs -> numOutputs + numHidden
    int         numInputs;
    int         numOutputs;
    int         numHidden;
    dictionary  idToNeuron;         // maps neuron id's to Neuron objects
    dictionary  neuronResponses;    // maps neuron id's to Neuron responses. Only used temporarily as 'bake' will add these values to each neuron it creates.
    dictionary  neuronBiases;
    Neuron@[]   orderedNeurons;     // list of neurons ordered by ID. This is initialized by bake() after all synapses added. Done for efficiency.
    bool        verbose = false;

    NeuralNetwork() {
        numInputs   = 0;
        numOutputs  = 0;
        numHidden   = 0;
    }

    bool isInputNeuron(Neuron@ n) {
        return n.id < 0;
    }

    bool isOutputNeuron(Neuron@ n) {
        return n.id >= 0 && n.id < numOutputs;
    }

    bool isHiddenNeuron(Neuron@ n) {
        return n.id >= numOutputs;
    }

    bool hasNeuron(int id) {
        return idToNeuron.exists(""+id);
    }

    Neuron@ getNeuron(int id) {
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

    // Executes a forward pass of the network
    float[] forward(float[] inputVec) {
        float[] outputVec;
        if (verbose) log("NeuralNetwork#forward", "Called");

        if (inputVec.length() != numInputs) {
            exception("NeuralNetwork#forward", "ERROR inputVec size does not match numInputs");
            return outputVec;
        }

        if (verbose) log("NeuralNetwork#forward", "Copying inputs to input neurons.");
        for (int i=0; i < orderedNeurons.length(); i++) {
            Neuron@ n = orderedNeurons[i];
            if (isInputNeuron(n)) {
                // It's an input neuron
                // We want input -1 (the first) to map to input array index 0 for example
                n.value = inputVec[(-n.id)-1];
                if (verbose) {
                    log("NeuralNetwork#forward", "Assigning input " + inputVec[(-n.id)-1] + " to neuron " + n.id);
                    n.debug();
                }
            }
            else {
                // We hit the end of the active input neurons
                break;
            }
        }

        // Update all hidden neurons
        for (int i=0; i < orderedNeurons.length(); i++) {
            Neuron@ n = orderedNeurons[i];
            if (isHiddenNeuron(n)) {
                forwardNeuron(n);
            }
        }

        // Update all output neurons
        for (int i=0; i < orderedNeurons.length(); i++) {
            Neuron@ n = orderedNeurons[i];
            if (isOutputNeuron(n)) {
                forwardNeuron(n);
            }
        }

        if (verbose) log("NeuralNetwork#forward", "Collecting outputs.");
        for (int i=0; i < numOutputs; i++) { outputVec.push_back(0); }
        for (int i=0; i < numOutputs; i++) {
            Neuron@ n = getNeuron(i);

            if (n !is null) {
                outputVec[n.id] = n.value;
            }
        }

        if (verbose) {
            string outputDebug = "";
            for (int i=0; i < outputVec.length(); i++) {
                outputDebug += outputVec[i] + ", ";
            }
            log("NeuralNetwork#forward", "Output vec: " + outputDebug);
        }
        return outputVec;
    }

    // Forwards a single neuron as part of the forward pass.
    void forwardNeuron(Neuron@ n) {
        float sum = 0.0;
        for (int j=0; j < n.incoming.length(); j++) {
            Synapse@ s = n.incoming[j];
            Neuron@ other = getNeuron(s.fromNeuron);
            if (verbose) {
                s.debug();
                other.debug();
                log("NeuralNetwork#forward", s.fromNeuron + "("+other.value+")" +
                    " ==" + s.weight + "==> " + n.id);
            }
            sum += s.weight * other.value;
        }

        n.sumIncoming = sum;
        n.value = sigmoid(n.bias + n.response * sum);
        if (verbose) log("NeuralNetwork#forward", "Set value to " + n.value);
    }

    float backPropagate(float[] inputVec, float[] idealVec) {
        // Phase 0: forward pass
        forward(inputVec);

        // PHASE 1: compute deltas 
        _backPropResetHasDelta();
        float totalError = _backPropComputeOutputDeltas(idealVec);
        _backPropComputeHiddenDeltas();

        // TODO: Maybe deltas for input neurons can be used somehow? Perhaps to update responses/biases.

        // PHASE 2: weight updates
        _backPropWeightUpdates();
        return totalError;
    }

    // Sets hasDelta = false for every neuron
    void _backPropResetHasDelta() {
        if (verbose) log("_backPropResetHasDelta", "Called");

        for (int i=0; i < orderedNeurons.length(); ++i) {
            Neuron@ n = orderedNeurons[i];
            n.hasDelta = false;
        }
    }

    // Computes the deltas for all output neurons
    float _backPropComputeOutputDeltas(float[] idealVec) {
        if (verbose) log("_backPropComputeOutputDeltas", "Called");
        float totalError = 0;

        for (int i=0; i < orderedNeurons.length(); ++i) {
            Neuron@ n = orderedNeurons[i];

            if (isOutputNeuron(n)) {
                float err = 0.5 * Maths::Pow(idealVec[n.id] - n.value, 2);
                totalError += err;
                float errWrtOut = n.value - idealVec[n.id]; // derivative of error function
                n.computeDelta(errWrtOut);
                n.hasDelta = true;
            }
        }

        return totalError;
    }
        
    // Computes deltas for all hidden neurons
    void _backPropComputeHiddenDeltas() {
        if (verbose) log("_backPropComputeHiddenDeltas", "Called");
        int[] hiddenList; // the ids of hidden neurons which haven't yet been updated
        // Push all hidden onto the list
        for (int i=0; i < orderedNeurons.length(); ++i) {
            Neuron@ n = orderedNeurons[i];
            if (isHiddenNeuron(n)) {
                hiddenList.push_back(n.id);
            }
        }

        int iteration = 0;
        while (hiddenList.length() > 0) {
            if (verbose) log("backPropagate", "Doing delta compute iteration " + iteration);
            // Iterate from the back so we can pop safely
            for (int i=hiddenList.length()-1; i >= 0; --i) {
                int id = hiddenList[i];
                bool computed = _backPropComputeHiddenDeltaForNeuron(getNeuron(id));
                if (computed) {
                    if (verbose) log("_backPropComputeHiddenDeltas", "Computed for neuron " + id);
                    hiddenList.removeAt(i);
                }
            }

            iteration++;
            if (iteration == 10) {
                exception("_backPropComputeHiddenDeltas", "Oh dear! Too many iterations :(");
            }
        }
    }

    // Returns true/false whether we were ready to compute the delta for this neuron
    // To be able to compute a delta for a hidden neuron, we need to already have the deltas
    // for all of the neurons it is connected to.
    bool _backPropComputeHiddenDeltaForNeuron(Neuron@ n) {
        if (verbose) log("_backPropComputeHiddenDeltaForNeuron", "Called");
        bool canComputeDelta = true;
        float sumOfDeltasTimesWeights = 0.0;

        for (int i=0; i < n.outgoing.length; i++) {
            Synapse@ syn = n.outgoing[i];
            Neuron@ toNeuron = getNeuron(syn.toNeuron);

            if (toNeuron.hasDelta) {
                sumOfDeltasTimesWeights += toNeuron.delta * syn.weight;
            }
            else {
                canComputeDelta = false;
                break;
            }
        }

        if (canComputeDelta) {
            n.computeDelta(sumOfDeltasTimesWeights);
            n.hasDelta = true;
            return true;
        }
        else {
            return false;
        }
    }
    
    // Updates the weights for all synapses
    void _backPropWeightUpdates() {
        if (verbose) log("_backPropWeightUpdates", "Called");

        // Iterate through every weight and update it
        for (int i=0; i < orderedNeurons.length(); ++i) {
            Neuron@ toNeuron = orderedNeurons[i];

            for (int j=0; j < toNeuron.incoming.length(); ++j) {
                Synapse@ syn = toNeuron.incoming[j];
                Neuron@ fromNeuron = getNeuron(syn.fromNeuron);
                syn.updateWeight(fromNeuron.value, toNeuron.delta);
            }
        }
    }

    // Loads the network from a string representation
    // returns true/false if parsing was successful
    bool loadFromString(string str) {
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
        if (innerParts.length() != 3) {
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
        numHidden = parseInt(metaBits[1]);
        numOutputs = parseInt(metaBits[2]);

        // Parse neurons bit
        // This bit contains neuron ids, neuron biases and responses
        if (innerParts[1].length() == 0) {
            log("NeuralNetwork#loadFromString", "WARNING neurons part is empty");
        }
        else {
            // Format of each string is "id,bias,response"
            string[]@ neuronStrings = innerParts[1].split("#");
            for (int i=0; i < neuronStrings.length(); i++) {
                string neuronStr = neuronStrings[i];
                log("NeuralNetwork#loadFromString", "neuronStr: " + neuronStr);
                string[]@ neuronBits = neuronStr.split(",");
                if (neuronBits.length() != 3) {
                    log("loadFromString", "ERROR Incorrect number of neuronBits: " + neuronBits.length());
                    return false;
                }
                string id = neuronBits[0];
                float bias = parseFloat(neuronBits[1]);
                float response = parseFloat(neuronBits[2]);
                neuronBiases.set(id, bias);
                neuronResponses.set(id, response);
            }
        }

        /*
        log("loadFromString", "numInputs = " + numInputs +
                ", numOutputs = " + numOutputs +
                );
                */

        if (innerParts[2].length() == 0) {
            log("NeuralNetwork#loadFromString", "WARNING synapses part is empty");
        }
        else {
            // Occasionally networks have no synapses, which crashed the server cause this check wasn't here
            // Parse synapses bit
            string[]@ synapseStrings = innerParts[2].split("#");
            for (int i=0; i < synapseStrings.length(); i++) {
                string synapseStr = synapseStrings[i];
                //log("NeuralNetwork#loadFromString", "synapseStr: " + synapseStr);
                string[]@ synapseBits = synapseStr.split(",");
                if (synapseBits.length() != 3) {
                    log("loadFromString", "ERROR Incorrect number of synapseBits: " + synapseBits.length());
                    return false;
                }
                int fromNeuron = parseInt(synapseBits[0]);
                int toNeuron = parseInt(synapseBits[1]);
                float weight = parseFloat(synapseBits[2]);
                addSynapse(fromNeuron, toNeuron, weight);
            }
        }

        //log("loadFromString", "Parsing finished!");
        return bake() && validate();
    }

    void addSynapse(int fromNeuron, int toNeuron, float weight) {
        //log("addSynapse", "Adding " + fromNeuron + "==" + weight + "==> " + toNeuron);
        Synapse s(fromNeuron, toNeuron, weight);

        // Add into/out if they don't exist yet
        if (!hasNeuron(fromNeuron)) {
            Neuron n(fromNeuron);
            addNeuron(@n);
        }

        if (!hasNeuron(toNeuron)) {
            Neuron n(toNeuron);
            addNeuron(@n);
        }

        Neuron@ toN = getNeuron(toNeuron);
        Neuron@ fromN = getNeuron(fromNeuron);
        toN.incoming.push_back(@s);
        fromN.outgoing.push_back(@s);
    }

    // Final step after loading is complete. This sets 'orderedNeurons'.
    // Returns true/false whether successful.
    bool bake() {
        //log("NeuralNetwork#bake", "Baking network");
        // Sort all the IDs numerically (string ordering doesn't do that because e.g. "10001" < "2"
        string[]@ everyID = idToNeuron.getKeys();
        int[] everyIntID;
        for (int i=0; i < everyID.length(); i++) {
            everyIntID.push_back(parseInt(everyID[i]));
        }
        everyIntID.sortAsc();

        for (int i=0; i < everyIntID.length(); i++) {
            string stringID = everyIntID[i];
            Neuron@ neuron;

            bool check = idToNeuron.get(stringID, @neuron);
            if (!check) {
                log("NeuralNetwork#bake", "ERROR couldn't find neuron with id: " + stringID);
                return false;
            }

            // Get bias and response information for non-input neurons
            if (!isInputNeuron(neuron)) {
                float bias;
                check = neuronBiases.get(stringID, bias);
                if (!check) {
                    bias = 0.0;
                }

                float response;
                check = neuronResponses.get(stringID, response);
                if (!check) {
                    response = 1.0;
                }

                neuron.bias = bias;
                neuron.response = response;
            }

            orderedNeurons.push_back(neuron);
        }
        //log("NeuralNetwork#bake", "Num active neurons: " + orderedNeurons.length());
        return true;
    }

    // Error checks the structure of the network
    bool validate() {
        log("validate", "Validating network...");

        if (orderedNeurons.length() == 0) {
            log("validate", "WARN no active neurons");
        }

        if (orderedNeurons.length() != idToNeuron.getSize()) {
            log("validate", "ERROR orderedNeurons length doesn't match idToNeuron size. Probably error in bake.");
            return false;
        }

        if (orderedNeurons.length() != numInputs + numHidden + numOutputs) {
            log("validate", "ERROR orderedNeurons length doesn't match numInputs + numHidden + numOutputs");
            return false;
        }

        int activeInputs = 0;
        int activeHidden = 0;
        int activeOutputs = 0;
        int synapseCount = 0;
        int stage = 0; // 0 for inputs, 1 for outputs, 2 for hidden
        for (int i=0; i < orderedNeurons.length(); i++) {
            Neuron@ n = orderedNeurons[i];
            if (n is null) {
                log("validate", "ERROR null neuron found");
                return false;
            }

            if (stage == 0) {
                if (isInputNeuron(n)) {
                }
                else if (isOutputNeuron(n)) {
                    stage = 1;
                }
                else {
                    log("validate", "ERROR unexpected hidden neuron " + n.id);
                }
            }
            else if (stage == 1) {
                if (isInputNeuron(n)) {
                    log("validate", "ERROR unexpected input neuron " + n.id);
                }
                else if (isOutputNeuron(n)) {
                }
                else {
                    stage = 2;
                }
            }
            else { // stage == 2
                if (isInputNeuron(n)) {
                    log("validate", "ERROR unexpected input neuron " + n.id);
                }
                else if (isOutputNeuron(n)) {
                    log("validate", "ERROR unexpected output neuron " + n.id);
                }
                else {
                }
            }

            if (isInputNeuron(n))
                activeInputs++;
            else if (isOutputNeuron(n))
                activeOutputs++;
            else
                activeHidden++;

            //n.debug();

            /*
            log("validate", "INFO neuron debug: id="+n.id +
                   ", incoming=" + n.incoming.length());
                   */
            for (int j=0; j < n.incoming.length(); j++) {
                synapseCount++;
                Synapse@ s = n.incoming[j];
                /*
                log("validate", "INFO synapse debug: into="+s.fromNeuron +
                        ", out="+s.toNeuron +
                        ", weight="+s.weight);
                        */
                if (s is null) {
                    log("validate", "ERROR null synapse found");
                    return false;
                }
                else if (!hasNeuron(s.fromNeuron)) {
                    log("validate", "ERROR broken synapse, fromNeuron=" + s.fromNeuron);
                    return false;
                }
                else if (!hasNeuron(s.toNeuron)) {
                    log("validate", "ERROR broken synapse, toNeuron=" + s.toNeuron);
                    return false;
                }
                else if (s.toNeuron != n.id) {
                    log("validate", "ERROR synapse doesn't output to right neuron");
                    return false;
                }
                else if (s.toNeuron < 0) {
                    log("validate", "ERROR synapse outputs to an input neuron");
                    return false;
                }
            }
        }

        if (activeInputs != numInputs) {
            log("validate", "ERROR wrong number of inputs");
            return false;
        }
        if (activeHidden != numHidden) {
            log("validate", "ERROR wrong number of hidden");
            return false;
        }
        if (activeOutputs != activeOutputs) {
            log("validate", "ERROR wrong number of outputs");
            return false;
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

shared class NetworkInputs {
    int   enemyDownUp       = 0; // -1 down, 0 none, 1 up
    int   enemyLeftRight    = 0; // -1 left, 0 none, 1 right
    int   enemyAction       = 0; // 0 none, 1 action1, 2 action2
    u8    enemyKnocked      = 0;
    u8    enemyKnightState  = KnightStates::normal;
    u8    enemySwordTimer   = 0;
    u8    enemyShieldTimer  = 0;
    bool  enemyDoubleSlash  = false;
    u32   enemySlideTime    = 0;
    //u32   enemyShieldDown   = 0;
    float enemyVelX         = 0.0;
    float enemyVelY         = 0.0;
    float enemyPosX         = 0.0; // normalized to be between 0 and 1, using map width
    float enemyPosY         = 0.0; // normalized to be between 0 and 1, using map height
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
    //u32   selfShieldDown    = 0;
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
        //result.push_back( enemyShieldDown  );
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
        //result.push_back( selfShieldDown  );
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

        float mapWidth = getMap().tilemapwidth * 8;
        float mapHeight = getMap().tilemapheight * 8;

        enemyKnocked = customGetKnocked(enemy);
        enemyKnightState = enemyInfo.state;
        enemySwordTimer = enemyInfo.swordTimer;
        enemyShieldTimer = enemyInfo.shieldTimer;
        enemyDoubleSlash = enemyInfo.doubleslash;
        enemySlideTime = enemyInfo.slideTime;
        //enemyShieldDown = enemyInfo.shield_down;
        enemyVelX = enemy.getVelocity().x;
        enemyVelY = enemy.getVelocity().y;
        enemyPosX = enemy.getPosition().x / mapWidth;
        enemyPosY = enemy.getPosition().y / mapHeight;

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

        selfKnocked = customGetKnocked(self);
        selfKnightState = selfInfo.state;
        selfSwordTimer = selfInfo.swordTimer;
        selfShieldTimer = selfInfo.shieldTimer;
        selfDoubleSlash = selfInfo.doubleslash;
        selfSlideTime = selfInfo.slideTime;
        //selfShieldDown = selfInfo.shield_down;
        selfVelX = self.getVelocity().x;
        selfVelY = self.getVelocity().y;
        selfPosX = self.getPosition().x / mapWidth;
        selfPosY = self.getPosition().y / mapHeight;

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

    u8 customGetKnocked(CBlob@ blob) {
        // getKnocked is not shared code so we can't use it
        if (!blob.exists("knocked"))
            return 0;
        return blob.get_u8("knocked");
    }
}

shared class NetworkOutputs {
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

    float[] vectorize() {
        float[] vec;
        vec.push_back(down ? 1 : -1);
        vec.push_back(up ? 1 : -1);
        vec.push_back(left ? 1 : -1);
        vec.push_back(right ? 1 : -1);
        vec.push_back(action1 ? 1 : -1);
        vec.push_back(action2 ? 1 : -1);
        vec.push_back(aimX);
        vec.push_back(aimY);
        return vec;
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

shared float sigmoid(float x) {
    return 1.0/(1.0 + Maths::Pow(CONST_E, -x));
}

shared float sigmoidDeriv(float x) {
    float sig = sigmoid(x);
    return sig * (1 - sig);
}

/*
shared float tanh(float x) {
    float em2x = Maths::Pow(CONST_E, -2*x);
    return (1-em2x) / (1+em2x);
}

shared float leakyRelu(float x) {
    // This might not actually give any performance advantage if it's compiled into a jump
    return (x > 0) ? x : 0.01*x;
}
*/

// Returns true/false if the given string contains a substring 'sub' starting at index i
shared bool stringCheck(string str, int i, string sub) {
    if (str.length() < sub.length()) {
        log("stringCheck", "WARN str.length < sub.length");
        return false;
    }

    string strSub = str.substr(i, sub.length());
    return strSub == sub;
}
