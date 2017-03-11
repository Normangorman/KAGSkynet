shared void log(string func_name, string msg)
{
    string fullScriptName = getCurrentScriptName();
    string[]@ parts = fullScriptName.split("/");
    string shortScriptName = parts[parts.length-1];
    u32 t = getGameTime();

    printf("[" + shortScriptName + "] [" + func_name + "] [" + t + "] " + msg);
}

shared void exception(string func_name, string msg) {
    log(func_name, msg);
    float x = 42 / XORRandom(0); // KABOOOM
}