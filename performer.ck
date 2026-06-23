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

while (true) {
    oin => now;
    while (oin.recv(msg)) {
        if (msg.address == "/hand/features") {
            msg.getFloat(0) => features[0];
            msg.getFloat(1) => features[1];
            msg.getFloat(2) => features[2];
            msg.getFloat(3) => features[3];

            if (handPresent) {
                knn.predict(features, 5, prob);
                0 => int best;
                for (1 => int i; i < 8; i++) {
                    if (prob[i] > prob[best]) i => best;
                }
                <<< "predicted class:", best >>>;
            }
        } else if (msg.address == "/hand/present") {
            msg.getFloat(0) $ int => handPresent;
        }
    }
}