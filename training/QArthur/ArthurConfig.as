const float CONST_E = 2.71828;
const int NUM_INPUTS = 2; // change this if inputs are changed
const int NUM_OUTPUTS = 1;
const float LEARNING_RATE = 0.01; // for backprop
const float SIGMOID_X_SCALAR = -4.9;

// 2 input, 2 hidden neuron, 1 output network
const string BACKPROP_TEST_NETWORK = "<network>2,2,1@@-1,1,1.0#-1,2,1.0#-2,1,1.0#-2,2,1.0#1,0,1.0#2,0,1.0</network>";
const string BACKPROP_TEST_NETWORK2 = "<network>3,10,4@@-1,4,1.0#-1,5,1.0#-1,6,1.0#-1,7,1.0#-1,8,1.0#-2,4,1.0#-2,5,1.0#-2,6,1.0#-2,7,1.0#-2,8,1.0#-3,4,1.0#-3,5,1.0#-3,6,1.0#-3,7,1.0#-3,8,1.0#4,9,1.0#4,10,1.0#4,11,1.0#4,12,1.0#4,13,1.0#5,9,1.0#5,10,1.0#5,11,1.0#5,12,1.0#5,13,1.0#6,9,1.0#6,10,1.0#6,11,1.0#6,12,1.0#6,13,1.0#7,9,1.0#7,10,1.0#7,11,1.0#7,12,1.0#7,13,1.0#8,9,1.0#8,10,1.0#8,11,1.0#8,12,1.0#8,13,1.0#9,0,1.0#9,1,1.0#9,2,1.0#9,3,1.0#10,0,1.0#10,1,1.0#10,2,1.0#10,3,1.0#11,0,1.0#11,1,1.0#11,2,1.0#11,3,1.0#12,0,1.0#12,1,1.0#12,2,1.0#12,3,1.0#13,0,1.0#13,1,1.0#13,2,1.0#13,3,1.0</network>";

const string IRIS_NETWORK = "<network>4,5,1@@-1,1,0.01#-1,2,0.01#-1,3,0.01#-1,4,0.01#-1,5,0.01#-2,1,0.01#-2,2,0.01#-2,3,0.01#-2,4,0.01#-2,5,0.01#-3,1,0.01#-3,2,0.01#-3,3,0.01#-3,4,0.01#-3,5,0.01#-4,1,0.01#-4,2,0.01#-4,3,0.01#-4,4,0.01#-4,5,0.01#1,0,0.01#2,0,0.01#3,0,0.01#4,0,0.01#5,0,0.01</network>";
const string IRIS_NETWORK_3_OUT = "<network>4,5,3@@-1,3,0.1#-1,4,0.1#-1,5,0.1#-1,6,0.1#-1,7,0.1#-2,3,0.1#-2,4,0.1#-2,5,0.1#-2,6,0.1#-2,7,0.1#-3,3,0.1#-3,4,0.1#-3,5,0.1#-3,6,0.1#-3,7,0.1#-4,3,0.1#-4,4,0.1#-4,5,0.1#-4,6,0.1#-4,7,0.1#3,0,0.1#3,1,0.1#3,2,0.1#4,0,0.1#4,1,0.1#4,2,0.1#5,0,0.1#5,1,0.1#5,2,0.1#6,0,0.1#6,1,0.1#6,2,0.1#7,0,0.1#7,1,0.1#7,2,0.1</network>";
const string IRIS_NETWORK_RAND_WEIGHTS = "<network>4,5,3@@-1,3,0.0725028410646#-1,4,0.186123033831#-1,5,0.0902995454873#-1,6,-0.0485877008502#-1,7,-0.188666367681#-2,3,-0.0399863586545#-2,4,-0.128396099659#-2,5,0.016672798659#-2,6,0.0512795064958#-2,7,0.12870586035#-3,3,-0.172083007701#-3,4,-0.156705680199#-3,5,-0.11952353564#-3,6,-0.184651064225#-3,7,-0.148681519014#-4,3,0.0761884666626#-4,4,-0.0920238123696#-4,5,0.0794472375759#-4,6,-0.0419100471955#-4,7,-0.15445854905#3,0,0.16898919947#3,1,0.0142299960639#3,2,-0.192151256112#4,0,0.15014850564#4,1,0.0153868642931#4,2,-0.115224192736#5,0,-0.0635301687314#5,1,0.132191639146#5,2,0.165354274221#6,0,-0.127505866164#6,1,0.111909447158#6,2,-0.0856108335325#7,0,0.0521591312118#7,1,-0.0404936850448#7,2,0.171878853405</network>";

// Species 
const float[][] IRIS_TRAIN_SET = {
    {5.1,3.5,1.4,0.2,1},
    {4.9,3.0,1.4,0.2,1},
    {4.7,3.2,1.3,0.2,1},
    {4.6,3.1,1.5,0.2,1},
    {5.0,3.6,1.4,0.2,1},
    {5.4,3.9,1.7,0.4,1},
    {4.6,3.4,1.4,0.3,1},
    {5.0,3.4,1.5,0.2,1},
    {4.4,2.9,1.4,0.2,1},
    {4.9,3.1,1.5,0.1,1},
    {5.4,3.7,1.5,0.2,1},
    {4.8,3.4,1.6,0.2,1},
    {4.8,3.0,1.4,0.1,1},
    {4.3,3.0,1.1,0.1,1},
    {5.8,4.0,1.2,0.2,1},
    {5.7,4.4,1.5,0.4,1},
    {5.4,3.9,1.3,0.4,1},
    {5.1,3.5,1.4,0.3,1},
    {5.7,3.8,1.7,0.3,1},
    {5.1,3.8,1.5,0.3,1},
    {5.4,3.4,1.7,0.2,1},
    {5.1,3.7,1.5,0.4,1},
    {4.6,3.6,1.0,0.2,1},
    {5.1,3.3,1.7,0.5,1},
    {4.8,3.4,1.9,0.2,1},
    {5.0,3.0,1.6,0.2,1},
    {5.0,3.4,1.6,0.4,1},
    {5.2,3.5,1.5,0.2,1},
    {5.2,3.4,1.4,0.2,1},
    {4.7,3.2,1.6,0.2,1},
    {4.8,3.1,1.6,0.2,1},
    {5.4,3.4,1.5,0.4,1},
    {5.2,4.1,1.5,0.1,1},
    {5.5,4.2,1.4,0.2,1},
    {4.9,3.1,1.5,0.2,1},
    {4.4,3.2,1.3,0.2,1},
    {5.0,3.5,1.6,0.6,1},
    {5.1,3.8,1.9,0.4,1},
    {4.8,3.0,1.4,0.3,1},
    {5.1,3.8,1.6,0.2,1},
    {4.6,3.2,1.4,0.2,1},
    {5.3,3.7,1.5,0.2,1},
    {5.0,3.3,1.4,0.2,1},
    {7.0,3.2,4.7,1.4,2},
    {6.4,3.2,4.5,1.5,2},
    {6.9,3.1,4.9,1.5,2},
    {5.5,2.3,4.0,1.3,2},
    {6.5,2.8,4.6,1.5,2},
    {5.7,2.8,4.5,1.3,2},
    {6.3,3.3,4.7,1.6,2},
    {4.9,2.4,3.3,1.0,2},
    {6.6,2.9,4.6,1.3,2},
    {5.2,2.7,3.9,1.4,2},
    {5.0,2.0,3.5,1.0,2},
    {5.9,3.0,4.2,1.5,2},
    {6.0,2.2,4.0,1.0,2},
    {6.1,2.9,4.7,1.4,2},
    {5.6,2.9,3.6,1.3,2},
    {6.7,3.1,4.4,1.4,2},
    {5.6,3.0,4.5,1.5,2},
    {5.8,2.7,4.1,1.0,2},
    {6.2,2.2,4.5,1.5,2},
    {5.6,2.5,3.9,1.1,2},
    {5.9,3.2,4.8,1.8,2},
    {6.1,2.8,4.0,1.3,2},
    {6.3,2.5,4.9,1.5,2},
    {6.1,2.8,4.7,1.2,2},
    {6.4,2.9,4.3,1.3,2},
    {6.6,3.0,4.4,1.4,2},
    {6.8,2.8,4.8,1.4,2},
    {6.7,3.0,5.0,1.7,2},
    {6.0,2.9,4.5,1.5,2},
    {5.7,2.6,3.5,1.0,2},
    {5.5,2.4,3.8,1.1,2},
    {5.5,2.4,3.7,1.0,2},
    {5.5,2.5,4.0,1.3,2},
    {5.5,2.6,4.4,1.2,2},
    {6.1,3.0,4.6,1.4,2},
    {5.8,2.6,4.0,1.2,2},
    {5.0,2.3,3.3,1.0,2},
    {5.6,2.7,4.2,1.3,2},
    {5.7,3.0,4.2,1.2,2},
    {5.7,2.9,4.2,1.3,2},
    {6.2,2.9,4.3,1.3,2},
    {5.1,2.5,3.0,1.1,2},
    {5.7,2.8,4.1,1.3,2},
    {6.3,3.3,6.0,2.5,3},
    {5.8,2.7,5.1,1.9,3},
    {7.1,3.0,5.9,2.1,3},
    {6.3,2.9,5.6,1.8,3},
    {6.5,3.0,5.8,2.2,3},
    {7.6,3.0,6.6,2.1,3},
    {4.9,2.5,4.5,1.7,3},
    {7.3,2.9,6.3,1.8,3},
    {6.7,2.5,5.8,1.8,3},
    {7.2,3.6,6.1,2.5,3},
    {6.5,3.2,5.1,2.0,3},
    {6.4,2.7,5.3,1.9,3},
    {6.8,3.0,5.5,2.1,3},
    {5.7,2.5,5.0,2.0,3},
    {5.8,2.8,5.1,2.4,3},
    {6.4,3.2,5.3,2.3,3},
    {6.5,3.0,5.5,1.8,3},
    {7.7,3.8,6.7,2.2,3},
    {7.7,2.6,6.9,2.3,3},
    {6.0,2.2,5.0,1.5,3},
    {6.9,3.2,5.7,2.3,3},
    {5.6,2.8,4.9,2.0,3},
    {7.7,2.8,6.7,2.0,3},
    {6.3,2.7,4.9,1.8,3},
    {6.7,3.3,5.7,2.1,3},
    {7.2,3.2,6.0,1.8,3},
    {6.2,2.8,4.8,1.8,3},
    {6.1,3.0,4.9,1.8,3},
    {6.4,2.8,5.6,2.1,3},
    {7.2,3.0,5.8,1.6,3},
    {7.4,2.8,6.1,1.9,3},
    {7.9,3.8,6.4,2.0,3},
    {6.4,2.8,5.6,2.2,3},
    {6.3,2.8,5.1,1.5,3},
    {6.1,2.6,5.6,1.4,3},
    {7.7,3.0,6.1,2.3,3},
    {6.3,3.4,5.6,2.4,3},
    {6.4,3.1,5.5,1.8,3},
    {6.7,3.0,5.2,2.3,3},
    {6.3,2.5,5.0,1.9,3},
    {6.5,3.0,5.2,2.0,3},
    {6.2,3.4,5.4,2.3,3},
    {5.9,3.0,5.1,1.8,3}
};

// 21 points from the main set
const float[][] IRIS_TEST_SET = {
    {6.0,3.0,4.8,1.8,3},
    {6.9,3.1,5.4,2.1,3},
    {6.7,3.1,5.6,2.4,3},
    {6.9,3.1,5.1,2.3,3},
    {5.8,2.7,5.1,1.9,3},
    {6.8,3.2,5.9,2.3,3},
    {6.7,3.3,5.7,2.5,3},
    {5.8,2.7,3.9,1.2,2},
    {6.0,2.7,5.1,1.6,2},
    {5.4,3.0,4.5,1.5,2},
    {6.0,3.4,4.5,1.6,2},
    {6.7,3.1,4.7,1.5,2},
    {6.3,2.3,4.4,1.3,2},
    {5.6,3.0,4.1,1.3,2},
    {5.0,3.2,1.2,0.2,1},
    {5.5,3.5,1.3,0.2,1},
    {4.9,3.6,1.4,0.1,1},
    {4.4,3.0,1.3,0.2,1},
    {5.1,3.4,1.5,0.2,1},
    {5.0,3.5,1.3,0.3,1},
    {4.5,2.3,1.3,0.3,1}
};