#include "Logging.as";
#include "NeuralNetwork.as";
#include "SkynetConfig.as";

bool hasCurrentNetwork = false;
NeuralNetwork@ currentNetwork;

void onInit(CBlob@ this) {
    this.set_f32(SUPERBOT_SCORE_PROP, 0.0);
}

void AddToScore(CBlob@ this, float value) {
    float score = this.get_f32(SUPERBOT_SCORE_PROP);
    this.set_f32(SUPERBOT_SCORE_PROP, score + value);
}

void onTick(CBlob@ this) {
    if (!getNet().isServer()) return;
    //log("onTick", "test");

    if (this.hasTag("dead")) {
        this.getCurrentScript().runFlags |= Script::remove_after_this;
        return;
    }

    if (!hasCurrentNetwork) {
        log("onTick", "WARN: No current network!");
        loadNeuralNetwork();
        return;
    }

    CBlob@ targetKnight = getTargetKnight(this);
    if (targetKnight !is null) {
        //log("onTick", "Target found");
        NetworkInputs inputs;
        inputs.loadFromBlobs(this, targetKnight);

        //log("onTick", "Running network");
        NetworkOutputs outputs = currentNetwork.evaluate(inputs);
        outputs.setBlobKeys(this);
    }
}

void loadNeuralNetwork() {
    // sets currentNetwork and hasCurrentNetwork
    //log("loadNeuralNetwork", "Trying to load network");
    if (getRules().exists(CURRENT_NETWORK_PROP)) {
        log("loadNeuralNetwork", "Network found in Rules! Activating brain.");
        bool success = getRules().get(CURRENT_NETWORK_PROP, @currentNetwork);
        if (!success) {
            log("loadNeuralNetwork", "ERROR failed to load network from rules");
        }
        else {
            hasCurrentNetwork = true;
        }
    }
}

CBlob@ getTargetKnight(CBlob@ this) {
    // Check if target is saved already
    if (this.exists("target knight id")) {
        u16 targetKnightID = this.get_netid("target knight id");
        CBlob@ targetKnight = getBlobByNetworkID(targetKnightID);
        
        if (targetKnight !is null && !targetKnight.hasTag("dead")) {
            return targetKnight;
        }
    }

    CBlob@[] knights;
    CBlob@[] targets;

    getBlobsByName("knight", knights);

    for (int i=0; i < knights.length; i++) {
        CBlob@ blob = knights[i];
        if (!blob.hasTag("dead") &&
                blob.getTeamNum() != this.getTeamNum()) {
            // Find insert index (keep sorted by distance)
            int ix;
            for (ix=0; ix < targets.length; ix++) {
                if (blob.getDistanceTo(this) <
                        targets[ix].getDistanceTo(this))
                    break;
            }

            targets.insert(ix, blob);
        }
    }

    if (targets.length > 0) {
        //log("getTargetKnight", "Found target knights: " + targets.length);
        this.set_netid("target knight id", targets[0].getNetworkID());
        return targets[0];
    }

    return null;
}
