#include "Logging.as";
#include "NeuralNetwork.as";
#include "SkynetConfig.as";

bool hasCurrentNetwork = false;
NeuralNetwork currentNetwork;

void onTick(CBlob@ this) {
    if (!getNet().isServer()) return;

    if (!hasCurrentNetwork) {
        loadNeuralNetwork();
        return;
    }

    CBlob@ targetKnight = getTargetKnight();
    if (targetKnight !is null) {
        log("onTick", "Target found");
        NetworkInputs inputs;
        inputs.loadFromBlobs(this, targetKnight);

        log("onTick", "Running network");
        NetworkOutputs outputs = currentNetwork.evaluate(inputs);
        outputs.setBlobKeys(this);
    }
}

void loadNeuralNetwork() {
    // sets currentNetwork and hasCurrentNetwork
    log("loadNeuralNetwork", "Trying to load network");
    if (!getRules().exists(NETWORK_RULES_PROP)) {
        log("loadNeuralNetwork", "Network rules prop found");
        currentNetwork = NeuralNetwork();
        bool success = currentNetwork.loadFromString(getRules().get_string(NETWORK_RULES_PROP));
        if (success) {
            log("loadNeuralNetwork", "Successfully loaded network!");
            hasCurrentNetwork = true;
        }
        else {
            log("loadNeuralNetwork", "Loading network failed.");
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
        log("Found target knights: " + targets.length);
        this.set_netid("target knight id", targets[0].getNetworkID());
        return targets[0];
    }

    return null;
}
