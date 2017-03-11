#define SERVER_ONLY
#include "KnightCommon.as";
#include "Knocked.as";
#include "Logging.as";

const float BLOCKS = 8.0;
const float POWER_SLASH_RANGE = 25.0; // refers to the distance travelled during the 1st slash
const float SLASH_RANGE = 36.0;
const float JAB_RANGE = 20.0;
const float KNIGHT_RADIUS = 7.5;
const float AVERAGE_ATTACK_RANGE = 14.0;
const u8 POWER_SLASH_DURATION = 11;
const u8 SLASH_DURATION = 14;
const u8 JAB_DURATION = 10;

namespace CombatState
{
    enum _
    {
        normal,
        charging,
        jabbing,
        slashing,
        powerslashing,
        shielding,
        shieldsliding,
        knocked
    }
}

void onInit(CBrain@ this)
{
	this.getCurrentScript().removeIfTag = "dead";
}

u8 GetCombatState(CBlob@ blob) {
    KnightInfo@ knight;
    blob.get("knightInfo", @knight);

    if (getKnocked(blob) > 0)
        return CombatState::knocked;
    else if (knight.state == KnightStates::normal)
        return CombatState::normal;
    else if (knight.state == KnightStates::sword_drawn)
        return CombatState::charging;
    else if (isShieldState(knight.state)) {
        // Removed temporarily since arthur's not going to shield slide
        return CombatState::shielding;
        /*
        if (knight.slideTime > 0) {
            return CombatState::shieldsliding;
        }
        else {
        }
        */
    }
    else if (inMiddleOfAttack(knight.state)) {
        if (knight.state == KnightStates::sword_power)
            return CombatState::slashing;
        else if (knight.state == KnightStates::sword_power_super)
            return CombatState::powerslashing;
        else
            return CombatState::jabbing;
    }
    return 255;
}

bool IsAttackingCombatState(u8 state) {
    return state == CombatState::jabbing ||
        state == CombatState::slashing ||
        state == CombatState::powerslashing;
}

void onTick(CBrain@ this) {
    // Check that knightInfo is set properly
    if (GetKnightInfo(this) is null) {
        log("onTick", "knightInfo not set properly!");
        return;
    }

    // Update target if needed
    CBlob@ blob = this.getBlob();
	CBlob@ target = this.getTarget();
	if (target is null || target.hasTag("dead"))
	{
        UpdateTarget(this);
        return;
    }

    u8 allyState = GetCombatState(blob);
    u8 enemyState = GetCombatState(target);
    f32 enemyDist = blob.getDistanceTo(target);
    u8 allySwordTimer = GetSwordTimer(this);
    u8 enemySwordTimer = GetSwordTimer(target.getBrain());

    bool advance = true;
    bool aimAtEnemy = true;
    bool shield = false;
    bool charge = false;

    if (allyState == CombatState::knocked) {
        // Can't do anything
        return;
    }
    else if (IsAttackingCombatState(allyState)) {
        // Decide whether to keep pushing to enemy or not
        if (WouldHitOther(allyState, allySwordTimer, enemyDist)) {
            advance = true;
            aimAtEnemy = true;
        }
        else {
            advance = false;
            aimAtEnemy = false;
        }

        if (allyState == CombatState::powerslashing && GetDoubleSlash(this) == false) {
            charge = true;
        }
    }
    else if (allyState == CombatState::shielding) {
        if (IsAttackingCombatState(enemyState)) {
            // Keep shielding
            shield = true;
            advance = false;
        }
        else {
            shield = false;
        }
    }
    else if (allyState == CombatState::charging) {
        charge = true;
        advance = true;

        bool shield = enemyState == CombatState::shielding;
        if (InAttackRange(blob, target) && !shield) {
            // They're in range and not shielding so jab them
            charge = false;
        }
        else if (CanDoubleSlash(this)) {
            if (allySwordTimer == KnightVars::slash_charge_limit - 1) {
                // Don't get stunned from charging too long
                charge = false;
                advance = false;
            }
            else if (WouldHitOther(CombatState::powerslashing, 0, enemyDist)) {
                // We would hit them so go for it
                charge = false;
            }
        }
        else if (CanSlash(this)) {
            if (WouldHitOther(CombatState::slashing, 0, enemyDist) && !shield) {
                charge = false;
            }
        }
    }
    else if (allyState == CombatState::normal) {
        charge = true;
        advance = true;

        if (enemyDist > 120.0) {
            charge = false;
        }
        else if (IsAttackingCombatState(enemyState)) {
            // Check if they will definitely hit us and shield if so
            if (WillDefinitelyHitOther(enemyState, enemySwordTimer, enemyDist)) {
                shield = true;
                advance = false;
            }
            else if (WouldHitOther(enemyState, enemySwordTimer, enemyDist)) {
                // They're attacking and might hit us so back off
                charge = true;
                advance = false;
                aimAtEnemy = false;
            }
        }
        else if (enemyState == CombatState::charging) {
            if (enemyDist < 24.0) {
                if (enemySwordTimer < 8 || 23 < enemySwordTimer && enemySwordTimer < 39) {
                    // Go for counter jab
                    charge = true;
                    advance = true;
                } 
                else {
                    shield = true;
                }
            }
            else {
                // Counter attack
                charge = true;
                advance = false;
                aimAtEnemy = false;
            }
        }
    }


    if (aimAtEnemy) {
        Aim(this, target.getPosition());
    }
    else {
        Vec2f delta = target.getPosition() - blob.getPosition();
        Aim(this, -delta);
    }

    if (advance) {
        MoveToTarget(this);
    }
    else {
        MoveAwayFromTarget(this);
    }

    if (shield) {
        DoShield(this);
    }

    if (charge) {
        ChargeAttack(this);
    }
    else {
        ReleaseAttack(this);
    }
}

bool WillDefinitelyHitOther(u8 state, u8 swordTimer, u8 otherDist) {
    // Tries to predict if we will definitely hit the other during this attack
    float remainingAttackDist = GetAttackRemainingDist(state, swordTimer);

    if (otherDist - KNIGHT_RADIUS < (remainingAttackDist + AVERAGE_ATTACK_RANGE) * 0.6) {
        return true;
    }
    else {
        return false;
    }
}

bool WouldHitOther(u8 state, u8 swordTimer, u8 otherDist) {
    // Tries to predict if we would hit the other during this attack
    float remainingAttackDist = GetAttackRemainingDist(state, swordTimer);

    if (otherDist - KNIGHT_RADIUS < remainingAttackDist + AVERAGE_ATTACK_RANGE) {
        return true;
    }
    else {
        return false;
    }
}

float GetAttackRemainingDist(u8 state, u8 swordTimer) {
    // Assumes that the knight is in the middle of an attack
    // Returns the estimated distance that the knight will travel while attacking
    float progress = GetAttackProgressPct(state, swordTimer);

    if (state == CombatState::jabbing) {
        return JAB_RANGE * progress;
    }
    else if (state == CombatState::slashing) {
        return SLASH_RANGE * progress;
    }
    else if (state == CombatState::powerslashing) {
        return POWER_SLASH_RANGE * progress + SLASH_RANGE;
    }
    else {
        log("GetAttackRemainingDist", "ERROR not in attacking state");
        return 0.0;
    }
}

float GetAttackProgressPct(u8 state, u8 swordTimer) {
    // Assumes that the knight is in the middle of an attack
    // Returns a number between 0 and 1 indicating how far through that attack we are
    if (state == CombatState::jabbing) {
        return float(swordTimer) / float(JAB_DURATION);
    }
    else if (state == CombatState::slashing) {
        return float(swordTimer) / float(SLASH_DURATION);
    }
    else if (state == CombatState::powerslashing) {
        return float(swordTimer) / float(POWER_SLASH_DURATION);
    }
    else {
        log("GetAttackProgressPct", "ERROR not in attacking state");
        return 0.0;
    }
}

bool UpdateTarget(CBrain@ this) {
    // Returns true if we have an active target, false if not
    CBlob@[] playerBlobs;
    CBlob@[] potentialTargets;
    getBlobsByTag("player", playerBlobs);

    for (int i=0; i < playerBlobs.length; i++) {
        CBlob@ blob = playerBlobs[i];
        if (blob !is this.getBlob() && !blob.hasTag("dead")) {
            potentialTargets.push_back(blob);
        }
    }

    bool foundTarget = false;
    uint16 closestBlobNetID;
    float closestDist = 99999.0;
    for (int i=0; i < potentialTargets.length; i++) {
        CBlob@ blob = potentialTargets[i];
        float dist = blob.getDistanceTo(this.getBlob());
        if (dist < closestDist) {
            foundTarget = true;
            closestDist = dist;
            closestBlobNetID = blob.getNetworkID();
        }
    }

    if (foundTarget) {
        this.SetTarget(getBlobByNetworkID(closestBlobNetID));
        return true;
    }
    else
        return false;
}

void MoveToTarget(CBrain@ this) {
    CBlob@ target = this.getTarget();
    CBlob@ blob = this.getBlob();
    Vec2f delta = target.getPosition() - blob.getPosition();
    Aim(this, target.getPosition());

    if (delta.x > 0) {
        blob.setKeyPressed(key_right, true);
        blob.SetFacingLeft(false);
    }
    else {
        blob.setKeyPressed(key_left, true);
        blob.SetFacingLeft(true);
    }

    if (delta.y < -8.0) {
        blob.setKeyPressed(key_up, true);
    }
    else {
        blob.setKeyPressed(key_up, false);
    }
}

void MoveAwayFromTarget(CBrain@ this, bool stayFacingThem = false) {
    CBlob@ target = this.getTarget();
    CBlob@ blob = this.getBlob();
    Vec2f delta = target.getPosition() - blob.getPosition();

    // Aim away from target
    if (!stayFacingThem) {
        Aim(this, blob.getPosition() - delta);
    }

    if (delta.x > 0) {
        blob.setKeyPressed(key_left, true);
        blob.SetFacingLeft(true);
    }
    else {
        blob.setKeyPressed(key_right, true);
        blob.SetFacingLeft(false);
    }
}

KnightInfo@ GetKnightInfo(CBrain@ this) {
    KnightInfo@ knight;
    this.getBlob().get("knightInfo", @knight);
    return knight;
}

u8 GetKnightState(CBrain@ this) {
    return GetKnightInfo(this).state;
}

string GetKnightStateName(CBrain@ this) {
    u8 state = GetKnightState(this);

    if (state == KnightStates::normal) return "normal";
    else if (state == KnightStates::shielding) return "shielding";
    else if (state == KnightStates::shielddropping) return "shielddropping";
    else if (state == KnightStates::shieldgliding) return "shieldgliding";
    else if (state == KnightStates::sword_drawn) return "sword_drawn";
    else if (state == KnightStates::sword_cut_mid) return "sword_cut_mid";
    else if (state == KnightStates::sword_cut_mid_down) return "sword_cut_mid_down";
    else if (state == KnightStates::sword_cut_up) return "sword_cut_up";
    else if (state == KnightStates::sword_cut_down) return "sword_cut_down";
    else if (state == KnightStates::sword_power) return "sword_power";
    else if (state == KnightStates::sword_power_super) return "sword_power_super";
    else return "UNKNOWN STATE " + state;
}

u8 GetSwordTimer(CBrain@ this) {
    return GetKnightInfo(this).swordTimer;
}

bool GetDoubleSlash(CBrain@ this) {
    return GetKnightInfo(this).doubleslash;
}

void Aim(CBrain@ this, Vec2f pos) {
    this.getBlob().setAimPos(pos);
}

void DoShield(CBrain@ this) {
    this.getBlob().setKeyPressed(key_action2, true);
}

void DoJump(CBrain@ this) {
    this.getBlob().setKeyPressed(key_up, true);
}

void ChargeAttack(CBrain@ this) {
    this.getBlob().setKeyPressed(key_action1, true);
}

void ReleaseAttack(CBrain@ this) {
    this.getBlob().setKeyPressed(key_action1, false);
}

bool CanJab(CBrain@ this) {
    return GetKnightState(this) == KnightStates::sword_drawn;
}

bool CanSlash(CBrain@ this) {
    return GetKnightState(this) == KnightStates::sword_drawn &&
        GetSwordTimer(this) > KnightVars::slash_charge;
}

bool CanDoubleSlash(CBrain@ this) {
    return GetKnightState(this) == KnightStates::sword_drawn &&
        GetSwordTimer(this) > KnightVars::slash_charge_level2;
}

bool CanTriggerSecondSlash(CBrain@ this, u8 thisCombatState) {
    return thisCombatState == CombatState::powerslashing &&
            !GetKnightInfo(this).doubleslash &&
            GetSwordTimer(this) > 4;
}

f32 GetAttackRange(CBrain@ this) {
    CBlob@ blob = this.getBlob();
	Vec2f vel = blob.getVelocity();
    Vec2f thinghy(1,0);
	f32 attack_distance = Maths::Min(DEFAULT_ATTACK_DISTANCE + Maths::Max(0.0f, 1.75f * blob.getShape().vellen * (vel * thinghy)), MAX_ATTACK_DISTANCE);
    return blob.getRadius() + attack_distance;
}

bool HasTempo(CBlob@ this, CBlob@ other) {
    // Returns true if this has been charging attack longer than other 
    if (other.getName() != "knight")
        return true;
    else {
        KnightInfo@ thisKnight;
        KnightInfo@ otherKnight;
        this.get("knightInfo", @thisKnight);
        other.get("knightInfo", @otherKnight);

        bool thisIsCharging = thisKnight.state == KnightStates::sword_drawn;
        bool otherIsCharging = otherKnight.state == KnightStates::sword_drawn;
        if (thisIsCharging && !otherIsCharging)
            return true;
        else if (!thisIsCharging && otherIsCharging)
            return false;
        else if (thisIsCharging && otherIsCharging) {
            return thisKnight.swordTimer >= otherKnight.swordTimer;
        }
        else {
            return false;
        }
    }
}

bool InAttackRange(CBlob@ this, CBlob@ other) {
    float attackRange = GetAttackRange(this.getBrain());
    float dist = Maths::Abs(other.getPosition().x - this.getPosition().x) - other.getRadius();
    return dist < attackRange;
}

bool DoSlashSimulation(CBlob@ this, CBlob@ other, bool doubleSlash = false) {
    /* Performs a simplified physics simulation to decide
     * whether, if 'this' slashes now, 'other' will be hit.
     * Returns true/false if other will be hit.
     */
    float maxDist = 40.0;
    if (doubleSlash) {
        maxDist *= 1.6;
    }

    float dist = Maths::Abs(other.getPosition().x - this.getPosition().x) - other.getRadius();
    return dist < maxDist;

    /*
    float attackRange = GetAttackRange(this.getBrain());
    float thisX = this.getPosition().x;
    float otherX = other.getPosition().x;
    float thisVelX = this.getVelocity().x;
    float otherVelX = other.getVelocity().x;
    int thisAccelDir = GetAccelDirection(this);
    int otherAccelDir = GetAccelDirection(other);
    float normalVelX = 2.75;
    float normalForceX = 30.0;
    float slashMoveForce = 34.0; // knight mass * 0.5
    float fakeSlashTime = KnightVars::slash_time;
    if (doubleSlash) fakeSlashTime *= 2;

    // A = F/M
    // V = 0.5 * M * A^2

    for (int iter=0; iter < fakeSlashTime; iter++) {
        // Slash hit detection
        // Find closest point on enemy to us
        float dist = Maths::Abs(otherX - thisX) - other.getRadius();
        if (dist < attackRange) {
            // We hit with slash
            //log("DoSlashSimulation", "Hit detected on iteration " + iter);
            return true;
        }
        
        // Physics update
        // this
        float thisTotalForceX = (normalForceX + slashMoveForce) * thisAccelDir;
        float a = thisTotalForceX / this.getMass();
        float vAdd = 0.5 * this.getMass() * Math::Pow(a, 2);

        // other
        float otherTotalForceX = (normalForceX + slashMoveForce) * thisAccelDir;
        thisX += thisVelX;
        otherX += otherVelX;
    }

    //log("DoSlashSimulation", "No hit detected");
    return false;
    */
}

int GetAccelDirection(CBlob@ blob) {
    // Looks at blob key presses and returns -1, 0 or 1
    // representing the direction the blob wants to move in.
    int dir = 0;
    if (blob.isKeyPressed(key_left))
        dir = -1;
    else if (blob.isKeyPressed(key_right))
        dir = 1;

    return dir;
}
