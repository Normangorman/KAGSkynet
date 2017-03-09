from ..NetworkStructs import loadDataSet, isKeyPressed, KnightStates, FLATMAP_HEIGHT, FLATMAP_WIDTH
from pymunk.vec2d import Vec2d
import json
import math

TRAIN_F = "C:/Users/Ben/Projects/kag/mods/Skynet/training/data/compiled17and20/nn_train_data.txt"

class FightState:
    def __init__(self):
        self.ally_health = 4
        self.enemy_health = 4
        self.distance_horiz = None
        self.distance_vert = None
        self.ally_aim_dir = None
        self.enemy_aim_dir = None
        self.ally_combat_state = None
        self.ally_movement_horiz = None
        self.ally_movement_vert = None
        self.enemy_combat_state = None
        self.enemy_movement_horiz = None
        self.enemy_movement_vert = None
        self.charge_advantage = None
    
    def __hash__(self):
        return hash(frozenset(self.__dict__.iteritems()))

    def __str__(self):
        ally_health = self.ally_health
        enemy_health = self.enemy_health
        distance_horiz = invert_dict(FightDistanceHoriz.__dict__).get(self.distance_horiz)
        distance_vert = invert_dict(FightDistanceVert.__dict__).get(self.distance_vert)
        ally_aim_dir = invert_dict(FightAim.__dict__).get(self.ally_aim_dir)
        enemy_aim_dir = invert_dict(FightAim.__dict__).get(self.enemy_aim_dir)
        ally_combat_state = invert_dict(FightCombatState.__dict__).get(self.ally_combat_state)
        ally_movement_horiz = invert_dict(FightMovementHoriz.__dict__).get(self.ally_movement_horiz)
        ally_movement_vert = invert_dict(FightMovementVert.__dict__).get(self.ally_movement_vert)
        enemy_combat_state = invert_dict(FightCombatState.__dict__).get(self.enemy_combat_state)
        enemy_movement_horiz = invert_dict(FightMovementHoriz.__dict__).get(self.enemy_movement_horiz)
        enemy_movement_vert = invert_dict(FightMovementVert.__dict__).get(self.enemy_movement_vert)
        charge_advantage = invert_dict(FightChargeAdvantage.__dict__).get(self.charge_advantage)

        return ("FightState(ally_health={0}, enemy_health={1}, distance_horiz={2}, distance_vert={3}".format(ally_health, enemy_health, distance_horiz, distance_vert)
                + ", ally_aim_dir={0}, enemy_aim_dir={1}".format(ally_aim_dir, enemy_aim_dir)
                + ", ally_combat_state={0}, enemy_combat_state={1}".format(ally_combat_state, enemy_combat_state)
                + ", ally_movement_horiz={0}, enemy_movement_horiz={1}".format(ally_movement_horiz, enemy_movement_horiz)
                + ", ally_movement_vert={0}, enemy_movement_vert={1}".format(ally_movement_vert, enemy_movement_vert)
                + ", charge_advantage={0}".format(charge_advantage))

          
class FightDistanceHoriz:
    TOUCHING = 0
    CLOSE = 1
    NEARBY = 2
    FAR = 3
    VERY_FAR = 4

    @staticmethod
    def recognize(k1, k2):
        dx = abs(k1.posX - k2.posX)
        blocks = dx / 8.0
        if blocks < 2:
            return FightDistanceHoriz.TOUCHING
        elif blocks < 4:
            return FightDistanceHoriz.CLOSE
        elif blocks < 6:
            return FightDistanceHoriz.NEARBY
        elif blocks < 8:
            return FightDistanceHoriz.FAR
        else:
            return FightDistanceHoriz.VERY_FAR

class FightDistanceVert:
    EVEN = 0
    SELF_HIGH = 1
    ENEMY_HIGH = 2

    @staticmethod
    def recognize(k1, k2):
        if k1.posY - k2.posY > 16:
            return FightDistanceVert.ENEMY_HIGH
        elif k2.posY - k1.posY > 16:
            return FightDistanceVert.SELF_HIGH
        else:
            return FightDistanceVert.EVEN

class FightAim:
    DOWN = 0
    AT_ENEMY = 1
    AWAY_FROM_ENEMY = 2

    @staticmethod
    def recognize(k1, k2):
        k1_k2_vec = Vec2d(k2.posX - k1.posX, k2.posY - k1.posY)
        k1_aim_vec = Vec2d(k1.aimX, k1.aimY)
        towards_angle = k1_aim_vec.get_angle_degrees_between(k1_k2_vec)
        away_angle = k1_aim_vec.get_angle_degrees_between(-k1_k2_vec)
        down_angle = k1_aim_vec.get_angle_degrees_between(Vec2d(0, 1))

        a = min([towards_angle, away_angle, down_angle])
        if a == towards_angle:
            return FightAim.AT_ENEMY
        elif a == away_angle:
            return FightAim.AWAY_FROM_ENEMY
        else:
            return FightAim.DOWN

class FightMovementHoriz:
    IDLE = 0
    ADVANCING = 1
    RETREATING = 2

    @staticmethod
    def recognize(k1, k2):
        k1_k2_vec = Vec2d(k2.posX - k1.posX, k2.posY - k1.posY)
        k1_movement_vec = Vec2d(k1.velX, k1.velY)
        if abs(k1_k2_vec.get_angle_degrees_between(k1_movement_vec)) < 90:
            return FightMovementHoriz.ADVANCING
        else:
            return FightMovementHoriz.RETREATING
        return FightMovementHoriz.IDLE

class FightMovementVert:
    IDLE = 0
    JUMPING = 1
    FALLING = 2
    CROUCHING = 3

    @staticmethod
    def recognize(k):
        if k.velY < -0.1:
            return FightMovementVert.JUMPING
        elif k.velY > 0.1:
            return FightMovementVert.FALLING

        if abs(k.velY + k.velX) < 0.1 and k.downUp == -1:
            return FightMovementVert.CROUCHING
        
        return FightMovementVert.IDLE

class FightCombatState:
    IDLE = 0
    KNOCKED = 1
    CHARGING_JAB_READY = 2
    CHARGING_SLASH_READY = 3
    CHARGING_DOUBLE_SLASH_READY = 4
    SHIELDING = 5
    SHIELD_DROPPING = 6
    SHIELD_SLIDING = 7
    JABBING = 8
    SLASHING = 9
    POWER_SLASHING = 10

    @staticmethod
    def recognize(k):
        if k.knocked > 0:
            return FightCombatState.KNOCKED
        elif k.knightstate == KnightStates.normal:
            return FightCombatState.IDLE
        elif k.knightstate == KnightStates.sword_drawn:
            if k.swordtimer < 16:
                return FightCombatState.CHARGING_JAB_READY
            elif k.swordtimer < 38:
                return FightCombatState.CHARGING_SLASH_READY
            else:
                return FightCombatState.CHARGING_DOUBLE_SLASH_READY
        elif KnightStates.is_shield_state(k.knightstate):
            if k.slidetime > 0:
                return FightCombatState.SHIELD_SLIDING
            elif k.aimY > k.posY and k.velY > 0:
                # TODO: maybe this calculation is wrong?
                return FightCombatState.SHIELDDROPPING
            else:
                return FightCombatState.SHIELDING
        elif KnightStates.is_jab_state(k.knightstate):
            return FightCombatState.JABBING
        elif k.knightstate == KnightStates.sword_power:
            return FightCombatState.SLASHING
        elif k.knightstate == KnightStates.sword_power_super:
            return FightCombatState.POWER_SLASHING

        return FightCombatState.IDLE

class FightChargeAdvantage:
    NONE = 0
    SELF = 1
    ENEMY = 2

    @staticmethod
    def recognize(k1, k2):
        if k1.knightstate == KnightStates.sword_drawn and k2.knightstate == KnightStates.sword_drawn:
            if k1.swordtimer > k2.swordtimer:
                return FightChargeAdvantage.SELF
            elif k1.swordtimer == k2.swordtimer:
                return FightChargeAdvantage.ENEMY
        return FightChargeAdvantage.NONE

def props(cls):
    """
    Iterate over the properties of a class
    """
    return [(i, cls.__dict__[i]) for i in cls.__dict__.keys() if i[:1] != '_']

def invert_dict(d):
    return dict(zip(d.values(), d.keys()))


def recognize_state(net_inputs):
    """
    NetworkInputs -> FightState
    """
    state = FightState()
    ally = net_inputs.selfKnightInputs
    enemy = net_inputs.enemyKnightInputs

    state.distance_horiz = FightDistanceHoriz.recognize(ally, enemy)
    state.distance_vert = FightDistanceVert.recognize(ally, enemy)

    # TODO: fix this
    #state.ally_health = int(round(ally.health))
    #state.enemy_health = int(round(enemy.health))
    state.ally_health = 4
    state.enemy_health = 4

    state.ally_aim_dir = FightAim.recognize(ally, enemy)
    state.enemy_aim_dir = FightAim.recognize(enemy, ally)

    state.ally_combat_state = FightCombatState.recognize(ally)
    state.ally_movement_horiz = FightMovementHoriz.recognize(ally, enemy)
    state.ally_movement_vert = FightMovementVert.recognize(ally)

    state.enemy_combat_state = FightCombatState.recognize(enemy)
    state.enemy_movement_horiz = FightMovementHoriz.recognize(enemy, ally)
    state.enemy_movement_vert = FightMovementVert.recognize(enemy)

    state.charge_advantage = FightChargeAdvantage.recognize(ally, enemy)

    return state


if __name__ == "__main__":
    match_data = loadDataSet(TRAIN_F)
    pattern_counts = {}
    pattern_list = []

    for match in match_data:
        for inputs, _ in match:
            inputs.selfKnightInputs.denormalizePosition()
            inputs.enemyKnightInputs.denormalizePosition()
            pattern = recognize_state(inputs)

            h = hash(pattern)
            if h not in pattern_counts:
                pattern_counts[h] = 1
                pattern_list.append(pattern)
            else:
                pattern_counts[h] += 1
            #print(pattern)

    print("COMMON PATTERNS:")
    pattern_list.sort(key=lambda p: pattern_counts[hash(p)], reverse=True)
    average_count = 0
    for pat in pattern_list:
        count = pattern_counts[hash(pat)]
        average_count += count / float(len(pattern_counts))
        print(count, hash(pat), str(pat))
    print("{0} unique patterns, average count {1}".format(len(pattern_list), average_count))