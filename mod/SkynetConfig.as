const bool TEST_MODE = true; // if true then don't communicate with the server. Use TEST_NETWORK_STR as network.

const string FRESH_NETWORK_PROP = "fresh network";
const string CURRENT_NETWORK_ID_PROP = "current network id";
const string CURRENT_NETWORK_PROP = "current network";
const string INCOMING_NETWORK_PROP = "incoming network";
const string CURRENT_METADATA_PROP = "server metadata";
const string INCOMING_METADATA_PROP = "incoming metadata";
const string SUPERBOT_FITNESS_VARS_PROP = "fitness vars";

const string SUPERBOT_TAG = "superbot";
const string SUPERBOT_NAME = "Arthur";
const string SUPERBOT_SCORE_PROP = "bot score";
const string NORMALBOT_NAME = "Henry";
const float CONST_E = 2.71828;
const float SIGMOID_X_SCALAR = -4.9;
const int NUM_INPUTS = 32; // change this if inputs are changed
const int NUM_OUTPUTS = 8;
const int MAX_IDLE_TICKS = 100;

// Coefficients for the fitness function
const float CO_AV_VEL = 2.0;
const float CO_DAMAGE = 100.0;
const float CO_DAM_BLOCKED = 2.0;
const float CO_ACTIVE = 10.0;

const int TCPR_PING_FREQUENCY = 150;


const string EXAMPLE_NETWORK_STR = "<network>32,8,1000001@5,6,0.000000#1000001,1000001,0.000000</network>";
// this test network causes the bot to mirror the enemy keypresses
const string TEST_NETWORK_STR = "<network>32,8,1000001@1,1000001,-1.0#1,1000002,1.0#2,1000003,-1.0#2,1000004,1.0#3,1000005,1.0</network>";
const string TEST_NETWORK_STR2 = "<network>32,8,1000001@</network>";
