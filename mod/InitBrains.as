// Attached to knight.cfg
// If the bot is a superbot then add SkynetBrain.as
// Else add KnightBrain.as
#include "Logging.as";
#include "SkynetConfig.as";

void onInit(CBlob@ this) {
    //log("onInit", "Called");
}

void onSetPlayer(CBlob@ this, CPlayer@ player) {
    //log("onSetPlayer", "Called. Adding brains");

    if (player is null) {
        //log("onSetPlayer", "Player is null");
        return;
    }
    else {
        if (player.hasTag(SUPERBOT_TAG)) {
            this.getBrain().AddScript("SkynetBrain.as");
        }
        else {
            this.getBrain().AddScript("KnightBrain.as");
        }
    }
}
