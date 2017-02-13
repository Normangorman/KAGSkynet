#include "Logging.as";
#include "SkynetConfig.as";

void onInit(CRules@ this) {
    // Create bots
    if (getNet().isServer()) {
        CPlayer@ superbot = AddBot(SUPERBOT_NAME);
        superbot.Tag(SUPERBOT_TAG);
        CPlayer@ bot = AddBot(NORMALBOT_NAME);
    }
}

void onTick(CRules@ this) {
    CPlayer@ superbot = getPlayerByUsername(SUPERBOT_NAME);
    CPlayer@ bot = getPlayerByUsername(NORMALBOT_NAME);
    if (superbot is null || bot is null) {
        log("onTick", "ERROR either superbot or bot is null");
        return;
    }

    if (superbot.getBlob() is null || bot.getBlob() is null) {
        log("onTick", "One of the bot blobs are null so assigning their teams.");
        superbot.server_setTeamNum(0);
        bot.server_setTeamNum(1);
        LoadNextMap();
    }
    else {
        log("onTick", "Both bots are in game successfully. Now removing script.");
        //this.getCurrentScript().runFlags |= Script::remove_after_this;
        this.RemoveScript("InitBots.as");
    }
}
