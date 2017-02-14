#include "Logging.as";
#include "NeuralNetwork.as";
#include "SkynetConfig.as";

bool hasCurrentNetwork = false;
bool loggedOnce = true;
NeuralNetwork@ currentNetwork;

void onInit(CBrain@ this) {
    //log("onInit", "Hook called");
    hasCurrentNetwork = false;
}

void DebugKeys(CBlob@ blob) {
    log("DebugKeys", "Keys pressed: " + 
            "down = " + blob.isKeyPressed(key_down) +
            ", up = " + blob.isKeyPressed(key_up) +
            ", left = " + blob.isKeyPressed(key_left) +
            ", right = " + blob.isKeyPressed(key_right) +
            ", action1 = " + blob.isKeyPressed(key_action1) +
            ", action2 = " + blob.isKeyPressed(key_action2));
}

void onTick(CBrain@ this) {
    if (!getNet().isServer()) return;

    //log("onTick", "test");
    CBlob@ blob = this.getBlob();

    if (blob.hasTag("dead")) {
        blob.getCurrentScript().runFlags |= Script::remove_after_this;
        return;
    }

    if (!hasCurrentNetwork) {
        log("onTick", "WARN: No current network!");
        loadNeuralNetwork();
        //loggedOnce = false;
        return;
    }

    CBlob@ targetKnight = getTargetKnight(blob);
    if (targetKnight !is null) {
        //log("onTick", "Target found");
        NetworkInputs inputs;
        inputs.loadFromBlobs(blob, targetKnight);

        //log("onTick", "Running network");
        NetworkOutputs outputs = currentNetwork.evaluate(inputs);
        outputs.setBlobKeys(blob);
        if (!loggedOnce)
            DebugKeys(blob);
        loggedOnce = true;
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

CBlob@ getTargetKnight(CBlob@ blob) {
    // Check if target is saved already
    if (blob.exists("target knight id")) {
        u16 targetKnightID = blob.get_netid("target knight id");
        CBlob@ targetKnight = getBlobByNetworkID(targetKnightID);
        
        if (targetKnight !is null && !targetKnight.hasTag("dead")) {
            return targetKnight;
        }
    }

    CBlob@[] knights;
    CBlob@[] targets;

    getBlobsByName("knight", knights);

    for (int i=0; i < knights.length; i++) {
        CBlob@ other = knights[i];
        if (!other.hasTag("dead") &&
                other.getTeamNum() != blob.getTeamNum()) {
            // Find insert index (keep sorted by distance)
            int ix;
            for (ix=0; ix < targets.length; ix++) {
                if (other.getDistanceTo(blob) <
                        targets[ix].getDistanceTo(blob))
                    break;
            }

            targets.insert(ix, other);
        }
    }

    if (targets.length > 0) {
        //log("getTargetKnight", "Found target knights: " + targets.length);
        blob.set_netid("target knight id", targets[0].getNetworkID());
        return targets[0];
    }

    return null;
}
