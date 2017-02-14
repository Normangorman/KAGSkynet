// Should be attached to rules
#include "Logging.as";
#include "SkynetConfig.as";
#include "NeuralNetwork.as";
#include "FitnessFunction.as";

void onInit(CRules@ this) {
    this.set_string(INCOMING_NETWORK_PROP, "");
    this.set_string(INCOMING_METADATA_PROP, "");
    //this.set(CURRENT_NETWORK_PROP, "");
    //this.set_u32(CURRENT_NETWORK_ID_PROP, 0);
    this.set_bool(FRESH_NETWORK_PROP, false);
    this.set_string(CURRENT_METADATA_PROP, "");
    this.addCommandID("sync metadata");

    if (!getNet().isServer()) return;
    if (TEST_MODE) {
        log("onInit", "TEST_MODE activated.");
        LoadTestNetwork(this);
    }
}

void onTick(CRules@ this) {
    if (!getNet().isServer()) {
        return;
    }
    /*
    NeuralNetwork nnet();

    if (getGameTime() % 90 == 0)
        nnet.loadFromString(EXAMPLE_NETWORK_STR);
        */
    
    if (TEST_MODE) return;

    if (getGameTime() % TCPR_PING_FREQUENCY == 0) {
        SendTCPRPing();
    }

    if (IsMeasuringFitness(this) && CheckIfBotIsIdle()) {
        log("onTick", "Bot has been idle too long. Returning an overly idle fitness value.");
        FitnessVars@ vars = GetFitnessVars();
        if (vars !is null) {
            SendFitnessValue(this, vars.computeOverlyIdleFitness());
        }
    }

    // Check for incoming metadata
    string incoming_metadata = this.get_string(INCOMING_METADATA_PROP);
    if (incoming_metadata.length() > 0) {
        log("onTick", "Found incoming metadata!");
        this.set_string(INCOMING_METADATA_PROP, "");
        getNet().server_SendMsg(incoming_metadata);
    }

    // Check for new incoming networks
    string incoming_network = this.get_string(INCOMING_NETWORK_PROP);
    if (incoming_network.length() > 0) {
        log("onTick", "Found incoming network!");
        tcpr("Incoming network acknowledged"); // server should see this over tcpr connection
        this.set_string(INCOMING_NETWORK_PROP, "");

        NeuralNetwork nnet();
        bool valid = nnet.loadFromString(incoming_network);
        
        if (valid) {
            this.set(CURRENT_NETWORK_PROP, nnet);
            this.set_bool(FRESH_NETWORK_PROP, true);
            LoadNextMap();
        }
        else {
            log("onTick", "Invalid network received.");
        }

        //u32 current_network_id = this.get_u32(CURRENT_NETWORK_ID_PROP);
        //this.set_u32(CURRENT_NETWORK_ID_PROP, current_network_id + 1); 
    }
}

bool IsMeasuringFitness(CRules@ this) {
    // We measure fitness whenever the server sends a new network
    return this.get_bool(FRESH_NETWORK_PROP);
}

bool CheckIfBotIsIdle() {
    FitnessVars@ vars = GetFitnessVars();
    if (vars is null) {
        return false;
    }
    else {
        //log("CheckIfBotIsIdle", "idleTicks = " + vars.idleTicks);
        return vars.idleTicks > MAX_IDLE_TICKS;
    }
}

/* gave up on getting this to sync: it's a chat message instead.
void SyncMetadata(CRules@ this) {
    string data = this.get_string(CURRENT_METADATA_PROP);
    log("SyncMetadata", "Syncing: " + data);
    CBitStream params;
    params.write_string(data);
    this.SendCommand(this.getCommandID("sync metadata"), params, true);
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params) {
    log("onCommand", "Hook called!");
    if (!getNet().isServer() && cmd == this.getCommandID("sync metadata")) {
        log("onCommand", "Got sync metadata cmd");
        string metadata = params.read_string();
        this.set_string(CURRENT_METADATA_PROP, metadata);
    }
}
*/

void onStateChange(CRules@ this, const u8 oldState) {
    if (!getNet().isServer()) return;
    // Detect game over
    if (this.getCurrentState() == GAME_OVER &&
            oldState != GAME_OVER) {
        int winningTeam = this.getTeamWon();
        log("onStateChange", "Detected game over! Winning team: " + winningTeam);

        // Try and find the superblob, its fitness vars and compute the fitness to send to the server.
        if (IsMeasuringFitness(this)) {
            FitnessVars@ vars = GetFitnessVars();
            if (vars !is null) {
                float fitness = vars.computeFitness();
                log("onStateChange", "Computed fitness = " + fitness);
                SendFitnessValue(this, fitness);
            }
        }
    }
}

void SendFitnessValue(CRules@ this, float fitness) {
    // Sends a fitness value over tcpr (hopefully the server is listening)
    // final argument to formatFloat is the min number of digits after the decimal point
    // idk what the second argument is really, maybe the min number of digits before the point?
    // wtf is the first argument though
    string fitnessString = formatFloat(fitness, '0', 0, 6);
    log("SendFitnessValue", "Sending: " + fitnessString);
    tcpr("Network fitness: " + fitnessString);
    getNet().server_SendMsg("FITNESS: " + fitness);
    this.set_bool(FRESH_NETWORK_PROP, false);
}

void SendTCPRPing() {
    tcpr("Ping");
}

FitnessVars@ GetFitnessVars() {
    CPlayer@ superbot = getPlayerByUsername(SUPERBOT_NAME);
    if (superbot is null) {
        log("GetFitnessVars", "ERROR: superbot is null");
        return null;
    }

    FitnessVars@ vars;
    bool check = superbot.get(SUPERBOT_FITNESS_VARS_PROP, @vars);
    if (!check) {
        log("onStateChange", "ERROR couldn't get FitnessVars from superbot");
        return null;
    }
    else {
        return vars;
    }
}

void onTCPRConnect(CRules@ this) {
    if (!getNet().isServer()) return;
    // Doing this allows sv_tcpr_everything to be set to 0 which saves a lot of transmissions
    tcpr("Client authenticated");
}

void LoadTestNetwork(CRules@ this) {
    log("LoadTestNetwork", "Loading test network");
    NeuralNetwork nnet();
    //bool valid = nnet.loadFromString(TEST_NETWORK_STR);
    bool valid = nnet.loadFromString(EXAMPLE_NETWORK_STR);
    
    if (valid) {
        this.set(CURRENT_NETWORK_PROP, nnet);
        this.set_bool(FRESH_NETWORK_PROP, true);
    }
}

CBlob@ GetSuperblob() {
    CBlob@[] blobs;
    getBlobsByTag(SUPERBOT_TAG, @blobs);
    if (blobs.length() != 1) {
        log("GetSuperblob", "ERROR invalid number of superblobs " + blobs.length());
        CBlob@[] knights;
        getBlobsByName("knight", @knights);
        for (int i=0; i < knights.length(); i++) {
            printf("" + knights[i].hasTag(SUPERBOT_TAG));
        }
        log("GetSuperblob", "Num knights: " + knights.length());

        return null;
    }
    else {
        return blobs[0];
    }
}
