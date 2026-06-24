// load training data
FileIO f;
f.open("./fingering_model.txt", FileIO.READ);
f.readInt(10) => int numExamples;
float trainingFeatures[numExamples][4];
int trainingLabels[numExamples];
for (0 => int i; i < numExamples; i++) {
    f.readFloat() => trainingFeatures[i][0];
    f.readFloat() => trainingFeatures[i][1];
    f.readFloat() => trainingFeatures[i][2];
    f.readFloat() => trainingFeatures[i][3];
    f.readInt(10) => trainingLabels[i];
}
f.close();

// train k-nearest neighbors
KNN2 knn;
knn.train(trainingFeatures, trainingLabels);

// OSC setup
OscIn oin;
OscMsg msg;
6448 => oin.port;
oin.addAddress("/hand/features");
oin.addAddress("/hand/present");

float features[4];
int handPresent;
float prob[8];
int currentClass;
int lastPredicted;

// pitch shift setup
adc => PitShift ps => Gain mute => dac;
adc => Gain regular => dac;
1.0 => ps.mix;
[1.0, 9.0/8, 5.0/4, 4.0/3, 3.0/2, 5.0/3, 15.0/8, 2.0] @=> float noteRatios[];

fun void oscListener() {
    while (true) {
        oin => now;
        while (oin.recv(msg)) {
            if (msg.address == "/hand/features") {
                msg.getFloat(0) => features[0];
                msg.getFloat(1) => features[1];
                msg.getFloat(2) => features[2];
                msg.getFloat(3) => features[3];

                if (handPresent) {
                    3.0 => mute.gain;
                    1.0 => regular.gain;

                    knn.predict(features, 5, prob);
                    0 => int best;
                    for (1 => int i; i < 8; i++) {
                        if (prob[i] > prob[best]) i => best;
                    }

                    if (best == lastPredicted) {
                        best => currentClass;
                        <<< currentClass >>>;
                        noteRatios[currentClass] => ps.shift;
                    }
                    best => lastPredicted;
                } else {
                    0.0 => mute.gain;
                    0.0 => regular.gain;
                }
            } else if (msg.address == "/hand/present") {
                msg.getFloat(0) $ int => handPresent;
            }
        }
    }
}
spork ~ oscListener();

while (true) { 1::second => now; }