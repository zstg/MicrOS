#include <stdio.h>

#define LEARNING_RATE 0.01
#define ITERATIONS 1000

double train(double x[], double y[], int n) {
    double w = 0.0; // Initial weight
    for (int i = 0; i < ITERATIONS; i++) {
        double gradient = 0.0;
        for (int j = 0; j < n; j++) {
            gradient += (w * x[j] - y[j]) * x[j];
        }
        gradient /= n;
        w -= LEARNING_RATE * gradient;
    }
    return w;
}

int main() {
    double x[] = {1, 2, 3, 4, 5};
    double y[] = {2, 4, 6, 8, 10}; // y = 2x
    int n = 5;

    double w = train(x, y, n);
    printf("Trained weight: %f\n", w);
    return 0;
}
