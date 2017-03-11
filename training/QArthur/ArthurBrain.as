#define SERVER_ONLY
#include "Logging.as"
#include "KnightCommon.as"

dictionary Q_TABLE; // maps state hashes to lists of expected action rewards
u8 BRAIN_FREQUENCY = 3; // make a decision every 'this number of' ticks
float DISCOUNT_FACTOR = 0.9659; // tied to the frequency. makes rewards 2 seconds in the future worth 50% as much as immediate.
float DEFAULT_ACTION_REWARD = 0;
u8 EXPLORATION_CHANCE = 20; // 1/20 chance to pick non-optimal action for exploration
float LEARNING_RATE = 0.3; // alpha
int NUM_ACTIONS = 54;
bool IS_GAME_OVER = false; // use this to detect when game finishes so we can do stuff like dumping the q table
float TOTAL_MATCH_REWARD = 0.0; // cumulative reward for the current match

bool BEGINNING_OF_MATCH = true; // flags whether we're at the beginning of match (RECENT_STATE not set yet)
FightState RECENT_STATE;
u8 RECENT_ACTION;
FightState RECENT_STATE_ENEMY_PERSPECTIVE;
u8 RECENT_ACTION_ENEMY;

// A W L A 
// D S R W
// N   N D
string[] ALL_ACTIONS = {
    "AWLA", "AWLW", "AWLD",
    "AWRA", "AWRW", "AWRD",
    "AWNA", "AWNW", "AWND",
    "ASLA", "ASLW", "ASLD",
    "ASRA", "ASRW", "ASRD",
    "ASNA", "ASNW", "ASND",

    "DWLA", "DWLW", "DWLD",
    "DWRA", "DWRW", "DWRD",
    "DWNA", "DWNW", "DWND",
    "DSLA", "DSLW", "DSLD",
    "DSRA", "DSRW", "DSRD",
    "DSNA", "DSNW", "DSND",

    "NWLA", "NWLW", "NWLD",
    "NWRA", "NWRW", "NWRD",
    "NWNA", "NWNW", "NWND",
    "NSLA", "NSLW", "NSLD",
    "NSRA", "NSRW", "NSRD",
    "NSNA", "NSNW", "NSND",
};

class KnightData {
    float   health;
    Vec2f   vel;
    Vec2f   pos;
    Vec2f   norm_aim;
    uint16  keys_pressed;
    u8      knight_state;
    u8      sword_timer;
    u8      knocked;
    bool    double_slash;
    u32     slide_time;

    KnightData(CBlob@ blob) {
        MovementVars@ vars = blob.getMovement().getVars();
        KnightInfo@ knight;
        bool exists = blob.get("knightInfo", @knight);
        if (!exists) {
            log("KnightData", "ERROR couldn't get knightInfo from blob");
            return;
        }

        health          = blob.getHealth();
        vel             = blob.getVelocity();
        pos             = blob.getPosition();
        blob.getAimDirection(norm_aim);
        keys_pressed    = vars.keys;
        knight_state    = knight.state;
        sword_timer     = knight.swordTimer;
        knocked         = blob.get_u8("knocked");
        double_slash    = knight.doubleslash;
        slide_time      = knight.slideTime;
    }

    u8 get_fight_health() {
        // Normal kag healths are floats with a max value of 2. They can also go negative.
        // Here, convert the health to an integer between 0 and 4. All negative healths are made 0.
        return Maths::Max(0, Maths::Round(health * 2));
    }

    u8 get_fight_distance_horiz(KnightData@ other) {
        float dx = Maths::Abs(other.pos.x - pos.x);
        float blocks = dx/8.0;

        if (blocks < 3) {
            return FightDistanceHoriz::TOUCHING;
        } else if (blocks < 5) {
            return FightDistanceHoriz::CLOSE;
        } else if (blocks < 7) {
            return FightDistanceHoriz::NEARBY;
        } else if (blocks < 9) {
            return FightDistanceHoriz::FAR;
        } else {
            return FightDistanceHoriz::VERY_FAR;
        }
    }

    u8 get_fight_distance_vert(KnightData@ other) {
        if (other.pos.y - pos.y > 16) {
            return FightDistanceVert::SELF_HIGH;
        } else if (pos.y - other.pos.y > 16) {
            return FightDistanceVert::ENEMY_HIGH;
        } else {
            return FightDistanceVert::EVEN;
        }
    }

    u8 get_fight_aim(KnightData@ other) {
        Vec2f delta = other.pos - pos;

        float at_angle = Maths::Abs(norm_aim.AngleWith(delta));
        float away_angle = Maths::Abs(norm_aim.AngleWith(-delta));

        float down_angle = Maths::Abs(norm_aim.AngleWith(Vec2f(0, 1)));
        //log("get_fight_aim", "at_angle=" + at_angle + ", away_angle=" + away_angle + ",down_angle=" + down_angle);

        float min = Maths::Min(Maths::Min(at_angle, away_angle), down_angle);
        
        if (min == at_angle) {
            return FightAim::AT_ENEMY;
        } else if (min == away_angle) {
            return FightAim::AWAY_FROM_ENEMY;
        } else {
            return FightAim::DOWN;
        }
    }

    u8 get_fight_movement_horiz(KnightData@ other) {
        Vec2f delta = other.pos - pos;

        if (vel.Length() < 0.1) {
            return FightMovementHoriz::IDLE;
        }

        if (Maths::Abs(delta.AngleWith(vel)) < 90) {
            return FightMovementHoriz::ADVANCING;
        } else {
            return FightMovementHoriz::RETREATING;
        }
    }

    u8 get_fight_movement_vert() {
        if (vel.y < -0.1) {
            return FightMovementVert::JUMPING;
        } else if (vel.y > 0.1) {
            return FightMovementVert::FALLING;
        } else if (vel.Length() < 0.1 && is_key_pressed(key_down)) {
            return FightMovementVert::CROUCHING;
        } else {
            return FightMovementVert::IDLE;
        }
    }

    u8 get_fight_combat_state() {
        if (knocked > 0) {
            return FightCombatState::KNOCKED;
        } else if (knight_state == KnightStates::normal) {
            return FightCombatState::IDLE;
        } else if (knight_state == KnightStates::sword_drawn) {
            if (sword_timer < 16) {
                return FightCombatState::CHARGING_JAB_READY;
            } else if (sword_timer < 39) {
                return FightCombatState::CHARGING_SLASH_READY;
            } else {
                return FightCombatState::CHARGING_DOUBLE_SLASH_READY;
            }
        } else if (isShieldState(knight_state)) {
            if (slide_time > 0) {
                return FightCombatState::SHIELD_SLIDING;
            } else if (knight_state == KnightStates::shielddropping) {
                return FightCombatState::SHIELD_DROPPING;
            } else {
                return FightCombatState::SHIELDING;
            }
        } else if (is_jab_state(knight_state)) {
            return FightCombatState::JABBING;
        } else if (knight_state == KnightStates::sword_power) {
            return FightCombatState::SLASHING;
        } else if (knight_state == KnightStates::sword_power_super) {
            return FightCombatState::POWER_SLASHING;
        }

        return FightCombatState::IDLE;
    }

    u8 get_fight_charge_advantage(KnightData@ other) {
        if (knight_state == KnightStates::sword_drawn && other.knight_state == KnightStates::sword_drawn) {
            if (sword_timer < other.sword_timer) {
                return FightChargeAdvantage::ENEMY;
            } else if (sword_timer > other.sword_timer) {
                return FightChargeAdvantage::SELF;
            }
        }
        return FightChargeAdvantage::NONE;
    }

    bool is_key_pressed(keys key) {
        return keys_pressed & key != 0;
    }

    bool is_jab_state(u8 s) {
        return KnightStates::sword_cut_mid <= s && s <= KnightStates::sword_cut_down;
    }

    u8 classify_action(KnightData@ other) {
        // Returns the action being made by the knight during this state
        string action_string = "";

        // Horizontal movement
        if (is_key_pressed(key_left)) {
            action_string += "A";
        } else if (is_key_pressed(key_right)) {
            action_string += "D";
        } else {
            action_string += "N";
        }

        // Vertical movement
        if (is_key_pressed(key_up)) {
            action_string += "W";
        } else {
            action_string += "S";
        }

        // Mouse
        if (is_key_pressed(key_action1)) {
            action_string += "L";
        } else if (is_key_pressed(key_action2)) {
            action_string += "R";
        } else {
            action_string += "N";
        }

        u8 aim = get_fight_aim(@other);
        if (aim == FightAim::AT_ENEMY) {
            action_string += "A";
        } else if (aim == FightAim::AWAY_FROM_ENEMY) {
            action_string += "W";
        } else {
            action_string += "D";
        }

        // Now look up the action in the action table
        for (int i=0; i < NUM_ACTIONS; i++) {
            if (ALL_ACTIONS[i] == action_string) {
                return i;
            }
        }
        log("classify_action", "ERROR generated a non-existent action string " + action_string);
        return 255;
    }
}

namespace FightDistanceHoriz {
    enum _ {
        TOUCHING = 0, // < 2.5 blocks
        CLOSE, // < 5 blocks
        NEARBY, // < 7 blocks
        FAR, // < 9 blocks
        VERY_FAR // > 9 blocks
    }
}

namespace FightDistanceVert {
    enum _ {
        EVEN = 0,
        SELF_HIGH,
        ENEMY_HIGH
    }
}

namespace FightAim {
    enum _ {
        DOWN = 0,
        AT_ENEMY,
        AWAY_FROM_ENEMY
    }
}

namespace FightMovementHoriz {
    enum _ {
        IDLE = 0,
        ADVANCING,
        RETREATING
    }
}

namespace FightMovementVert {
    enum _ {
        IDLE = 0,
        JUMPING, FALLING, CROUCHING
    }
}

namespace FightCombatState {
    enum _ {
        IDLE = 0,
        KNOCKED,
        CHARGING_JAB_READY,
        CHARGING_SLASH_READY,
        CHARGING_DOUBLE_SLASH_READY,
        SHIELDING,
        SHIELD_DROPPING,
        SHIELD_SLIDING,
        JABBING,
        SLASHING,
        POWER_SLASHING
    }
}

namespace FightChargeAdvantage {
    enum _ {
        NONE = 0,
        SELF,
        ENEMY
    }
}

class FightState {
    u8 ally_health = 0; // in hearts up to 4
    u8 enemy_health = 0;
    u8 distance_horiz = 0;
    u8 distance_vert = 0;
    u8 ally_aim_dir = 0;
    u8 enemy_aim_dir = 0;
    u8 ally_combat_state = 0;
    u8 enemy_combat_state = 0;
    u8 ally_movement_horiz = 0;
    u8 enemy_movement_horiz = 0;
    u8 ally_movement_vert = 0;
    u8 enemy_movement_vert = 0;
    u8 charge_advantage = 0;

    FightState(KnightData@ ally, KnightData@ enemy) {
        ally_health  = ally.get_fight_health();
        enemy_health = enemy.get_fight_health();

        distance_horiz = ally.get_fight_distance_horiz(@enemy);
        distance_vert  = ally.get_fight_distance_vert(@enemy);

        ally_aim_dir = ally.get_fight_aim(@enemy);
        enemy_aim_dir = enemy.get_fight_aim(@ally);

        ally_combat_state = ally.get_fight_combat_state();
        enemy_combat_state = enemy.get_fight_combat_state();

        ally_movement_horiz = ally.get_fight_movement_horiz(@enemy);
        enemy_movement_horiz = enemy.get_fight_movement_horiz(@ally);

        ally_movement_vert = ally.get_fight_movement_vert();
        enemy_movement_vert = enemy.get_fight_movement_vert();

        charge_advantage = ally.get_fight_charge_advantage(@enemy);
    }

    void debug() {
        log("FightState#debug", "ally_health=" + ally_health
            + ", enemy_health=" + enemy_health
            + ", distance_horiz=" + distance_horiz
            + ", distance_vert=" + distance_vert
            + ", ally_aim_dir=" + ally_aim_dir
            + ", enemy_aim_dir=" + enemy_aim_dir
            + ", ally_combat_state=" + ally_combat_state
            + ", enemy_combat_state=" + enemy_combat_state
            + ", ally_movement_horiz=" + ally_movement_horiz
            + ", enemy_movement_horiz=" + enemy_movement_horiz
            + ", ally_movement_vert=" + ally_movement_vert
            + ", enemy_movement_vert=" + enemy_movement_vert
            + ", charge_advantage=" + charge_advantage
            );
    }

    string repr() {
        return (ally_health + ',' + enemy_health + ',' + distance_horiz + ',' + distance_vert + ',' + ally_aim_dir + ','
                + enemy_aim_dir + ',' + ally_combat_state + ',' + enemy_combat_state + ',' + ally_movement_horiz + ',' 
                + enemy_movement_horiz + ',' + ally_movement_vert + ',' + enemy_movement_vert + ',' + charge_advantage);
    }
}

u8 q_decide(FightState state) {
    // Decide on what action to take based on the current state
    string state_repr = state.repr();
    float[]@ action_rewards;
    bool state_exists = Q_TABLE.get(state_repr, @action_rewards);
    if (state_exists) {
        if (XORRandom(EXPLORATION_CHANCE) == 1) {
            log("q_decide", "Exploring random action");
            // Pick a random action for exploration
            u8 rand_action = XORRandom(NUM_ACTIONS);
            return rand_action;
        }
        else {
            // Pick the action we think is optimal right now
            u8 best_action;
            float best_reward = -999999;

            for (u8 i=0; i < action_rewards.length(); i++) {
                float reward = action_rewards[i];
                if (reward > best_reward) {
                    best_reward = reward;
                    best_action = i;
                }
            }

            //log("q_decide", "Best reward is " + best_reward + ", best action is " + best_action + " " + ALL_ACTIONS[best_action]);
            return best_action;
        }
    }
    else {
        q_add_new_state(state);
        u8 rand_action = XORRandom(NUM_ACTIONS);
        return rand_action;
    }
}

void q_add_new_state(FightState state) {
    // Adds a newly seen state to the q table
    string state_repr = state.repr();
    if (Q_TABLE.exists(state_repr)) {
        log("q_add_new_state", "ERROR state already exists! " + state_repr);
        return;
    }

    float[] action_rewards;
    action_rewards.resize(NUM_ACTIONS);
    for (int i=0; i < NUM_ACTIONS; i++) {
        action_rewards[i] = DEFAULT_ACTION_REWARD;
    }

    //log("q_add_new_state", "Inserting new state " + state_repr);
    Q_TABLE.set(state_repr, @action_rewards);
}

float q_reward(FightState state1, FightState state2) {
    float reward = 0.0;

    // Use float cause u8 can't be negative
    reward -= float(state2.enemy_health) - float(state1.enemy_health);
    reward += float(state2.ally_health) - float(state1.ally_health);
    /*
    log("q_reward", "" + float(state2.enemy_health) + " - " + float(state1.enemy_health));
    log("q_reward", "" + float(state2.ally_health) + " - " + float(state1.ally_health));
    log("q_reward", "" + reward);
    */
    return reward;
}

void q_learn(FightState state1, FightState state2, u8 action) {
    if (action > NUM_ACTIONS) {
        log("q_learn", "ERROR invalid action");
        return;
    }
    float reward = q_reward(state1, state2);

    string s1_repr = state1.repr();
    string s2_repr = state2.repr();
    float[]@ s1_action_rewards;
    float[]@ s2_action_rewards;
    if (!Q_TABLE.exists(s1_repr)) {
        //log("q_learn", "WARN state1 doesn't exist in Q table so adding it: " + s1_repr);
        q_add_new_state(state1);
    }
    if (!Q_TABLE.exists(s2_repr)) {
        //log("q_learn", "WARN state2 doesn't exist in Q table so adding it: " + s2_repr);
        q_add_new_state(state2);
    }
    Q_TABLE.get(state1.repr(), @s1_action_rewards);
    Q_TABLE.get(state2.repr(), @s2_action_rewards);

    float q_old = s1_action_rewards[action];
    float max_s2_reward = -999999;
    for (int i=0; i < NUM_ACTIONS; i++) {
        float r = s2_action_rewards[i];
        if (r > max_s2_reward) {
            max_s2_reward = r;
        }
    }

    float q_new = q_old + LEARNING_RATE * (reward + DISCOUNT_FACTOR * max_s2_reward - q_old);
    s1_action_rewards[action] = q_new;
    /*
    log("q_learn", "q_old=" + q_old
            + ", action=" + action
            + ", reward=" + reward
            + ", max_s2_reward=" + max_s2_reward
            + ", q_new=" + q_new
            );
            */
}

void dump_q_table(string file_path) {
    log("dump_q_table", "Saving to " + file_path);
    ConfigFile cfg();

    string[]@ states = Q_TABLE.getKeys();
    float[]@ action_rewards;
    for (int i=0; i < states.length(); i++) {
        string state_repr = states[i];
        Q_TABLE.get(state_repr, @action_rewards);
        cfg.addArray_f32(state_repr, action_rewards);
    }

    cfg.saveFile(file_path);
}

void perform_action(CBlob@ this, CBlob@ target, u8 action) {
    if (action >= NUM_ACTIONS) {
        log("perform_action", "ERROR invalid action " + action);
        return;
    } else if (this is null || target is null) {
        log("perform_action", "ERROR either blob or target is null");
        return;
    }
    string action_string = ALL_ACTIONS[action];

    // Wipe keys
    this.setKeyPressed(key_up, false);
    this.setKeyPressed(key_down, false);
    this.setKeyPressed(key_left, false);
    this.setKeyPressed(key_right, false);
    this.setKeyPressed(key_action1, false);
    this.setKeyPressed(key_action2, false);


    if (action_string[0] == "A"[0]) {
        this.setKeyPressed(key_left, true);
    } else if (action_string[0] == "D"[0]) {
        this.setKeyPressed(key_right, true);
    }

    if (action_string[1] == "W"[0]) {
        this.setKeyPressed(key_up, true);
    } else if (action_string[1] == "S"[0]) {
        this.setKeyPressed(key_down, true);
    }

    if (action_string[2] == "L"[0]) {
        this.setKeyPressed(key_action1, true);
    } else if (action_string[2] == "R"[0]) {
        this.setKeyPressed(key_action2, true);
    }

    Vec2f target_dir = target.getPosition() - this.getPosition();
    Vec2f down_dir(0, 1);
    if (action_string[3] == "A"[0]) {
        this.setAimPos(this.getPosition() + target_dir);
    } else if (action_string[3] == "W"[0]) {
        this.setAimPos(this.getPosition() + target_dir);
    } else {
        this.setAimPos(this.getPosition() + down_dir);
    }
}

void run_tests() {
    log("run_tests", "Running tests...");
    // Mock up a couple of states where the ally jabs the enemy
    FightState s1();
    s1.ally_health = 4;
    s1.enemy_health = 4;
    s1.distance_horiz = FightDistanceHoriz::TOUCHING;
    s1.distance_vert = FightDistanceVert::EVEN;
    s1.ally_aim_dir = FightAim::AT_ENEMY;
    s1.enemy_aim_dir = FightAim::AT_ENEMY;
    s1.ally_combat_state = FightCombatState::CHARGING_JAB_READY;
    s1.enemy_combat_state = FightCombatState::IDLE;
    s1.ally_movement_horiz = FightMovementHoriz::IDLE;
    s1.enemy_movement_horiz = FightMovementHoriz::IDLE;
    s1.ally_movement_vert = FightMovementVert::IDLE;
    s1.enemy_movement_vert = FightMovementVert::IDLE;
    s1.charge_advantage = FightChargeAdvantage::NONE;

    FightState s2();
    s2.ally_health = 4;
    s2.enemy_health = 3;
    s2.distance_horiz = FightDistanceHoriz::TOUCHING;
    s2.distance_vert = FightDistanceVert::EVEN;
    s2.ally_aim_dir = FightAim::AT_ENEMY;
    s2.enemy_aim_dir = FightAim::AT_ENEMY;
    s2.ally_combat_state = FightCombatState::JABBING;
    s2.enemy_combat_state = FightCombatState::KNOCKED;
    s2.ally_movement_horiz = FightMovementHoriz::IDLE;
    s2.enemy_movement_horiz = FightMovementHoriz::IDLE;
    s2.ally_movement_vert = FightMovementVert::IDLE;
    s2.enemy_movement_vert = FightMovementVert::IDLE;
    s2.charge_advantage = FightChargeAdvantage::NONE;

    // Test q_reward
    log("run_tests", "TESTING q_reward");
    float got = q_reward(s1, s2);
    float want = 1.0;
    if (got != want) {
        log("run_tests", "Test failed: q_reward. got=" + got + ", want=" + want);
    }

    // Test q_add_new_state
    log("run_tests", "TESTING q_add_new_state");
    q_add_new_state(s1);

    if (!Q_TABLE.exists(s1.repr())) {
        log("run_tests", "Test failed: q_add_new_state. key not found in Q_TABLE");
    }

    float[]@ action_rewards;
    bool exists = Q_TABLE.get(s1.repr(), @action_rewards);
    if (!exists) {
        log("run_tests", "Test failed: q_add_new_state. Couldn't retrieve action rewards");
    }

    if (action_rewards.length() != NUM_ACTIONS) {
        log("run_tests", "Test failed: q_add_new_state. Not enough actions");
    }

    // Check that retrieved rewards list is modifiable
    action_rewards[0] = 10.0;
    float[]@ action_rewards2;
    Q_TABLE.get(s1.repr(), @action_rewards2);
    if (action_rewards2[0] != 10.0) {
        log("run_tests", "Test failed: action_rewards is not modifiable");
    }

    // Test q_decide
    log("run_tests", "TESTING q_decide");
    u8 action = q_decide(s1);

    if (action != 0) {
        // This test will only succeed 95% of the time
        // Since we set the reward for action 0 to 10.0 earlier, it will likely be the returned action
        // But there's a chance it won't be
        log("run_tests", "Test failed: action != 0");
    }

    if (action >= NUM_ACTIONS) {
        log("run_tests", "Test failed: Invalid action returned!");
    }
    action_rewards[0] = 0.0;

    // Test q_learn
    log("run_tests", "TESTING q_learn");
    u8 test_action = 3; // doesn't really matter which one is picked
    q_learn(s1, s2, test_action); // enemy health going down (good)

    if (!Q_TABLE.exists(s2.repr())) {
        log("run_tests", "Test failed: q_learn. s2 wasn't added");
    }

    float[]@ s1_action_rewards;
    Q_TABLE.get(s1.repr(), @s1_action_rewards);
    if (!(s1_action_rewards[test_action] > 0)) {
        log("run_tests", "Test failed: q_learn. didn't update s1 action reward properly");
    }

    q_learn(s2, s1, test_action); // enemy health going up (bad)
    float[]@ s2_action_rewards;
    Q_TABLE.get(s2.repr(), @s2_action_rewards);
    if (!(s2_action_rewards[test_action] < 0)) {
        log("run_tests", "Test failed: q_learn. didn't update s2 action reward properly");
    }

    dump_q_table("test_qtable.cfg");
    Q_TABLE.deleteAll(); // reset it
    log("run_tests", "Finished");
}

void onSetPlayer(CBlob@ this, CPlayer@ player) {
    if (player is null) {
        return;
    }

    if (player.getUsername() == "Arthur") {
        log("onSetPlayer", "Tagging Arthur");
        this.Tag("Arthur");
    }
}

void onTick(CBrain@ this) {
    // Why is the CBrain onTick used as well as the CBlob onTick?
    // CBrain hooks seem to deactivate if the blob dies, so fatal damage is not detected.
    // So the learning stuff is mostly done in the CBlob tick
    // BUT we can't perform actions in a CBlob tick so do that here
    if (!BEGINNING_OF_MATCH) {
        perform_action(@this.getBlob(), @this.getTarget(), RECENT_ACTION);
    }
}

void onTick(CBlob@ this) {
    if (!this.hasTag("Arthur")) {
        return;
    }

	CBlob@ target = this.getBrain().getTarget();
	if (target is null)
	{
        UpdateTarget(this.getBrain());
        return;
    }

    if (!BEGINNING_OF_MATCH && RECENT_STATE.ally_health == 0) { // we're dead
        return;
    }

    if (getGameTime() % BRAIN_FREQUENCY == 0) {
        log("onTick(CBlob)", "Q_TABLE size " + Q_TABLE.getSize() + ", TOTAL_MATCH_REWARD=" + TOTAL_MATCH_REWARD);
        KnightData ally_knight(@this);
        KnightData enemy_knight(@target);
        FightState state(@ally_knight, @enemy_knight);
        FightState state_enemy_perspective(@enemy_knight, @ally_knight);
        //state.debug();

        if (!BEGINNING_OF_MATCH) {
            log("onTick", "Learning from me. Reward " + q_reward(RECENT_STATE, state)
                    + ", old health " + RECENT_STATE.ally_health
                    + ", current health " + state.ally_health
                    );
            q_learn(RECENT_STATE, state, RECENT_ACTION);
            TOTAL_MATCH_REWARD += q_reward(RECENT_STATE, state);
            //log("onTick", "Learning from enemy");
            q_learn(RECENT_STATE_ENEMY_PERSPECTIVE, state_enemy_perspective, RECENT_ACTION_ENEMY);
        }

        // Make a decision
        u8 action = q_decide(state);

        RECENT_STATE = state;
        RECENT_ACTION = action;
        BEGINNING_OF_MATCH = false;

        RECENT_STATE_ENEMY_PERSPECTIVE = state_enemy_perspective;
        RECENT_ACTION_ENEMY = enemy_knight.classify_action(ally_knight);
    }
}

/*
void onStateChange(CRules@ this, const u8 oldState) {
    if (this.getCurrentState() == GAME_OVER && oldState != GAME_OVER) {
        onGameOver();
    }
}
*/

void onReload(CBlob@ this) {
    log("onReload", ":)");
    run_tests();
}

void onRestart(CRules@ this) {
    log("onRestart", "Rules restart! Total reward for last match: " + TOTAL_MATCH_REWARD);
    BEGINNING_OF_MATCH = true;
    TOTAL_MATCH_REWARD = 0.0;
    dump_q_table("qtable" + XORRandom(99999999) + ".cfg");
}

bool UpdateTarget(CBrain@ this) {
    // Returns true if we have an active target, false if not
    CBlob@[] playerBlobs;
    CBlob@[] potentialTargets;
    getBlobsByTag("player", playerBlobs);

    for (int i=0; i < playerBlobs.length; i++) {
        CBlob@ blob = playerBlobs[i];
        if (blob !is this.getBlob() && !blob.hasTag("dead") && blob.getTeamNum() != this.getBlob().getTeamNum()) {
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