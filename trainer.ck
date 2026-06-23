global Wekinator wek;
wek.clear();

wek.inputDims(4);
wek.outputDims(1);
wek.taskType(AI.Classification);
wek.modelType(AI.KNN);
wek.setProperty(AI.KNN, "k", 5);
wek.setProperty(AI.Classification, "classes", 8);

// OSC setup
OscIn  oin;
OscMsg msg;
6448 => oin.port;
oin.addAddress("/hand/features");
oin.addAddress("/hand/present");

// data variable initialization
float features[4];
int handPresent;
int exampleCounts[8];
float trainingFeatures[0][4];
int trainingLabels[0];

// fingering names
string fingeringNames[8];
"root" => fingeringNames[0];
"2nd" => fingeringNames[1];
"3rd" => fingeringNames[2];
"4th" => fingeringNames[3];
"5th" => fingeringNames[4];
"6th" => fingeringNames[5];
"7th" => fingeringNames[6];
"octave" => fingeringNames[7];

// listens for osc updates
fun void oscListener() {
    while (true) {
        oin => now;
        while (oin.recv(msg)) {
            if (msg.address == "/hand/features") {
                msg.getFloat(0) => features[0];
                msg.getFloat(1) => features[1];
                msg.getFloat(2) => features[2];
                msg.getFloat(3) => features[3];
            } else if (msg.address == "/hand/present") {
                msg.getFloat(0) $ int => handPresent;
            }
        }
    }
}
spork ~ oscListener();

// keyboad input
KBHit kb;

// listens for keyboard updates
fun void keyListener() {
    while (true) {
        kb => now;
        while (kb.more()) {
            kb.getchar() => int key;

            // ascii 0-7
            if (key >= 48 && key <= 55) {
                key - 48 => int label;
                if (handPresent) {
                    trainingFeatures << features;
                    trainingLabels << label;
                    exampleCounts[label]++;
                    <<< "Recorded", fingeringNames[label], "(", exampleCounts[label], "examples so far)" >>>;
                }
            }

            // S (save)
            else if (key == 115) {
                FileIO f;
                f.open("./fingering_model.txt", FileIO.WRITE);
                f <= trainingLabels.size() <= "\n";
                for (0 => int i; i < trainingLabels.size(); i++) {
                    f <= trainingFeatures[i][0] <= " "
                      <= trainingFeatures[i][1] <= " "
                      <= trainingFeatures[i][2] <= " "
                      <= trainingFeatures[i][3] <= " "
                      <= trainingLabels[i] <= "\n";
                }
                f.close();
                <<< "Saved", trainingLabels.size(), "examples" >>>;
            }

            // P (print sample counts)
            else if (key == 112) {
                <<< "─── Example counts ───", "" >>>;
                for (0 => int i; i < 8; i++) {
                    <<< "[", i, "]", fingeringNames[i], ":", exampleCounts[i], "examples" >>>;
                }
                <<< "──────────────────────", "" >>>;
            }

            // Q (quit)
            else if (key == 113) {
                me.exit();
            }
        }
    }
}
spork ~ keyListener();

while (true) { 1::second => now; }