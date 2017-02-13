#include "Logging.as";
#include "SkynetConfig.as";

class FitnessVars {
    u32 startTime       = 0;
    float averageVel    = 0;
    u32 velMeasurements = 0;
    float damageDealt   = 0;
    float damageBlocked = 0;
    float damageTaken   = 0;
    u32 idleTicks       = 0;
    u32 totalIdle       = 0;

    float computeFitness() {
        u32 matchTime = getGameTime() - startTime;
        // the proportion of the total damage that we dealt
        float damageProportion = 0.0;
        if (damageDealt + damageTaken > 0) {
            damageProportion = damageDealt / (damageDealt + damageTaken);
        }

        float activeProportion = 0.0; 
        if (matchTime > 0) {
            activeProportion = 1.0 - idleTicks / Maths::Pow(matchTime, 1); // idk a better way to convert to float
        }

        float v = CO_AV_VEL * averageVel;
        float d = CO_DAMAGE * damageProportion;
        float b = CO_DAM_BLOCKED * damageBlocked;
        float a = CO_ACTIVE * activeProportion;
        float fitness = v + d + b + a;

        log("computeFitness", "SUMMARY: " + 
                "averageVel = " + averageVel + 
                ", damageDealt = " + damageDealt +
                ", damageBlocked = " + damageBlocked +
                ", damageTaken = " + damageTaken +
                ", idleTicks = " + idleTicks +
                ", matchTime = " + matchTime +
                ", damageProportion = " + damageProportion +
                ", activeProportion = " + activeProportion +
                ", v = " + v + 
                ", d = " + d + 
                ", b = " + b + 
                ", a = " + a +
                ", fitness = " + fitness
           );

        return fitness;
    }
}
