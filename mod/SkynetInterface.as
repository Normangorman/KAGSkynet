#include "SkynetConfig.as";
#include "Logging.as";

void onInit(CRules@ this)
{
}

void onRender(CRules@ this)
{
	GUI::SetFont("menu");

    int lineSpacing = 14;
    Vec2f topLeftPtr(8, 100);
    GUI::DrawText("What's going on here?", topLeftPtr, color_white);
    topLeftPtr.y += lineSpacing;

    GUI::DrawText("A genetic algorithm is learning to play knight by doing 1v1s against another bot.", topLeftPtr, color_white);
    topLeftPtr.y += lineSpacing;

    GUI::DrawText("Arthur is the learning bot and Henry is a bot with predefined behaviour.", topLeftPtr, color_white);
    topLeftPtr.y += lineSpacing;

    GUI::DrawText("Once Arthur has mastered beating Henry then he will be ready to play against humans!", topLeftPtr, color_white);
    topLeftPtr.y += lineSpacing;

    GUI::DrawText("It will probably take about 30 generations (about 9000 games) before Arthur starts fighting well.", topLeftPtr, color_white);
    topLeftPtr.y += lineSpacing * 2;

    //GUI::DrawText(this.get_string(CURRENT_METADATA_PROP), topLeftPtr, color_white);
}
