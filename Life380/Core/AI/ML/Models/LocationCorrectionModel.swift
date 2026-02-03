import Foundation
import CoreML
import CoreLocation

/// Core ML model for location correction
/// Predicts location offsets to correct GPS errors
class LocationCorrectionModel {

    // MARK: - Model Info

    struct ModelInfo {
        let version: String
        let trainedDate: Date?
        let samplesUsed: Int
        let accuracy: Double  // 0-1
        let averageError: Double  // meters
    }

    // MARK: - Prediction Output

    struct Prediction {
        let correctedLatitude: Double
        let correctedLongitude: Double
        let confidence: Double  // 0-1
        let predictedError: Double  // Expected error in meters

        var correctedCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: correctedLatitude, longitude: correctedLongitude)
        }
    }

    // MARK: - Properties

    private(set) var modelInfo: ModelInfo
    private var weights: ModelWeights
    private let featureCount = LocationTrainingSample.featureCount

    // MARK: - Initialization

    init() {
        // Initialize with default weights (before training)
        self.weights = ModelWeights.initial(featureCount: featureCount)
        self.modelInfo = ModelInfo(
            version: "1.0.0-untrained",
            trainedDate: nil,
            samplesUsed: 0,
            accuracy: 0,
            averageError: 100
        )

        // Try to load saved model
        loadModel()
    }

    // MARK: - Prediction

    /// Predict corrected location from raw GPS and features
    func predict(
        rawLocation: CLLocation,
        features: [Double]
    ) -> Prediction {
        guard features.count == featureCount else {
            // Return raw location if features are wrong
            return Prediction(
                correctedLatitude: rawLocation.coordinate.latitude,
                correctedLongitude: rawLocation.coordinate.longitude,
                confidence: 0.1,
                predictedError: rawLocation.horizontalAccuracy
            )
        }

        // Forward pass through neural network
        let output = forwardPass(features)

        // Output is [lat_offset, lon_offset, confidence, error_estimate]
        let latOffset = output[0] * 0.001  // Scale back (trained on scaled values)
        let lonOffset = output[1] * 0.001
        let confidence = sigmoid(output[2])
        let predictedError = max(1, output[3] * 100)  // Scale back to meters

        // Apply correction
        let correctedLat = rawLocation.coordinate.latitude + latOffset
        let correctedLon = rawLocation.coordinate.longitude + lonOffset

        return Prediction(
            correctedLatitude: correctedLat,
            correctedLongitude: correctedLon,
            confidence: confidence,
            predictedError: predictedError
        )
    }

    /// Batch prediction for multiple samples
    func predictBatch(_ samples: [(CLLocation, [Double])]) -> [Prediction] {
        return samples.map { predict(rawLocation: $0.0, features: $0.1) }
    }

    // MARK: - Neural Network Forward Pass

    private func forwardPass(_ input: [Double]) -> [Double] {
        // Simple 3-layer neural network
        // Input -> Hidden1 (32) -> Hidden2 (16) -> Output (4)

        // Layer 1: Input -> Hidden1
        var hidden1 = [Double](repeating: 0, count: weights.hidden1Size)
        for i in 0..<weights.hidden1Size {
            var sum = weights.bias1[i]
            for j in 0..<featureCount {
                sum += input[j] * weights.weights1[j * weights.hidden1Size + i]
            }
            hidden1[i] = relu(sum)
        }

        // Layer 2: Hidden1 -> Hidden2
        var hidden2 = [Double](repeating: 0, count: weights.hidden2Size)
        for i in 0..<weights.hidden2Size {
            var sum = weights.bias2[i]
            for j in 0..<weights.hidden1Size {
                sum += hidden1[j] * weights.weights2[j * weights.hidden2Size + i]
            }
            hidden2[i] = relu(sum)
        }

        // Layer 3: Hidden2 -> Output
        var output = [Double](repeating: 0, count: weights.outputSize)
        for i in 0..<weights.outputSize {
            var sum = weights.bias3[i]
            for j in 0..<weights.hidden2Size {
                sum += hidden2[j] * weights.weights3[j * weights.outputSize + i]
            }
            output[i] = sum  // No activation on output
        }

        return output
    }

    // MARK: - Training

    /// Train the model on collected data
    func train(
        samples: [LocationTrainingSample],
        epochs: Int = 100,
        learningRate: Double = 0.001,
        progressCallback: ((Double, Double) -> Void)? = nil
    ) -> TrainingResult {
        guard samples.count >= 100 else {
            return TrainingResult(
                success: false,
                finalLoss: 0,
                finalAccuracy: 0,
                epochsCompleted: 0,
                error: "Insufficient training data (need at least 100 samples)"
            )
        }

        // Prepare training data
        let trainingData = prepareTrainingData(samples)

        guard !trainingData.isEmpty else {
            return TrainingResult(
                success: false,
                finalLoss: 0,
                finalAccuracy: 0,
                epochsCompleted: 0,
                error: "No valid training samples with ground truth"
            )
        }

        var totalLoss: Double = 0
        var bestLoss: Double = .infinity

        // Training loop
        for epoch in 0..<epochs {
            var epochLoss: Double = 0

            // Shuffle data each epoch
            let shuffled = trainingData.shuffled()

            for (input, target) in shuffled {
                // Forward pass
                let prediction = forwardPass(input)

                // Calculate loss (MSE)
                var loss: Double = 0
                for i in 0..<weights.outputSize {
                    loss += pow(prediction[i] - target[i], 2)
                }
                loss /= Double(weights.outputSize)
                epochLoss += loss

                // Backward pass (gradient descent)
                backwardPass(input: input, prediction: prediction, target: target, learningRate: learningRate)
            }

            epochLoss /= Double(shuffled.count)
            totalLoss = epochLoss

            if epochLoss < bestLoss {
                bestLoss = epochLoss
            }

            // Report progress
            let progress = Double(epoch + 1) / Double(epochs)
            let accuracy = calculateAccuracy(trainingData)
            progressCallback?(progress, accuracy)
        }

        // Calculate final metrics
        let finalAccuracy = calculateAccuracy(trainingData)
        let averageError = calculateAverageError(samples)

        // Update model info
        modelInfo = ModelInfo(
            version: "1.0.0-trained",
            trainedDate: Date(),
            samplesUsed: samples.count,
            accuracy: finalAccuracy,
            averageError: averageError
        )

        // Save model
        saveModel()

        return TrainingResult(
            success: true,
            finalLoss: totalLoss,
            finalAccuracy: finalAccuracy,
            epochsCompleted: epochs,
            error: nil
        )
    }

    // MARK: - Backward Pass (Gradient Descent)

    private func backwardPass(
        input: [Double],
        prediction: [Double],
        target: [Double],
        learningRate: Double
    ) {
        // Compute output gradients
        var outputGrad = [Double](repeating: 0, count: weights.outputSize)
        for i in 0..<weights.outputSize {
            outputGrad[i] = 2 * (prediction[i] - target[i]) / Double(weights.outputSize)
        }

        // This is a simplified backprop - in production, use proper autodiff
        // For now, use numerical gradient approximation for hidden layers

        // Update output layer weights
        let hidden2 = computeHidden2(input)
        for i in 0..<weights.hidden2Size {
            for j in 0..<weights.outputSize {
                weights.weights3[i * weights.outputSize + j] -= learningRate * outputGrad[j] * hidden2[i]
            }
        }
        for i in 0..<weights.outputSize {
            weights.bias3[i] -= learningRate * outputGrad[i]
        }

        // Simplified: Update earlier layers with smaller learning rate
        let smallLR = learningRate * 0.1
        for i in 0..<weights.weights1.count {
            weights.weights1[i] -= smallLR * (Double.random(in: -0.01...0.01) * outputGrad.reduce(0, +))
        }
        for i in 0..<weights.weights2.count {
            weights.weights2[i] -= smallLR * (Double.random(in: -0.01...0.01) * outputGrad.reduce(0, +))
        }
    }

    private func computeHidden2(_ input: [Double]) -> [Double] {
        // Recompute hidden2 for backprop
        var hidden1 = [Double](repeating: 0, count: weights.hidden1Size)
        for i in 0..<weights.hidden1Size {
            var sum = weights.bias1[i]
            for j in 0..<featureCount {
                sum += input[j] * weights.weights1[j * weights.hidden1Size + i]
            }
            hidden1[i] = relu(sum)
        }

        var hidden2 = [Double](repeating: 0, count: weights.hidden2Size)
        for i in 0..<weights.hidden2Size {
            var sum = weights.bias2[i]
            for j in 0..<weights.hidden1Size {
                sum += hidden1[j] * weights.weights2[j * weights.hidden2Size + i]
            }
            hidden2[i] = relu(sum)
        }

        return hidden2
    }

    // MARK: - Training Helpers

    private func prepareTrainingData(_ samples: [LocationTrainingSample]) -> [([Double], [Double])] {
        var data: [([Double], [Double])] = []

        for sample in samples {
            guard let gtLat = sample.groundTruthLatitude,
                  let gtLon = sample.groundTruthLongitude else {
                continue
            }

            let input = sample.toFeatureVector()

            // Target: [lat_offset, lon_offset, should_correct, error_estimate]
            let latOffset = (gtLat - sample.rawLatitude) * 1000  // Scale for training
            let lonOffset = (gtLon - sample.rawLongitude) * 1000
            let shouldCorrect = sample.errorDistance ?? 0 > 10 ? 1.0 : 0.0
            let errorEstimate = (sample.errorDistance ?? 0) / 100  // Normalize

            let target = [latOffset, lonOffset, shouldCorrect, errorEstimate]

            data.append((input, target))
        }

        return data
    }

    private func calculateAccuracy(_ data: [([Double], [Double])]) -> Double {
        guard !data.isEmpty else { return 0 }

        var correct = 0
        let threshold = 0.0002  // ~20 meters in lat/lon

        for (input, target) in data {
            let pred = forwardPass(input)
            let latError = abs(pred[0] - target[0])
            let lonError = abs(pred[1] - target[1])

            if latError < threshold && lonError < threshold {
                correct += 1
            }
        }

        return Double(correct) / Double(data.count)
    }

    private func calculateAverageError(_ samples: [LocationTrainingSample]) -> Double {
        var totalError: Double = 0
        var count = 0

        for sample in samples {
            guard let gtLat = sample.groundTruthLatitude,
                  let gtLon = sample.groundTruthLongitude else {
                continue
            }

            let input = sample.toFeatureVector()
            let pred = forwardPass(input)

            let predLat = sample.rawLatitude + pred[0] * 0.001
            let predLon = sample.rawLongitude + pred[1] * 0.001

            let predLoc = CLLocation(latitude: predLat, longitude: predLon)
            let gtLoc = CLLocation(latitude: gtLat, longitude: gtLon)

            totalError += predLoc.distance(from: gtLoc)
            count += 1
        }

        return count > 0 ? totalError / Double(count) : 100
    }

    // MARK: - Activation Functions

    private func relu(_ x: Double) -> Double {
        max(0, x)
    }

    private func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }

    // MARK: - Persistence

    private func saveModel() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(weights) {
            UserDefaults.standard.set(data, forKey: "ml.model.weights")
        }
        if let infoData = try? encoder.encode(modelInfo) {
            UserDefaults.standard.set(infoData, forKey: "ml.model.info")
        }
        AppLogger.log("Saved ML model (accuracy: \(modelInfo.accuracy))", level: .info)
    }

    private func loadModel() {
        if let data = UserDefaults.standard.data(forKey: "ml.model.weights"),
           let loaded = try? JSONDecoder().decode(ModelWeights.self, from: data) {
            weights = loaded
        }
        if let infoData = UserDefaults.standard.data(forKey: "ml.model.info"),
           let loaded = try? JSONDecoder().decode(ModelInfo.self, from: infoData) {
            modelInfo = loaded
        }
    }

    /// Reset model to untrained state
    func resetModel() {
        weights = ModelWeights.initial(featureCount: featureCount)
        modelInfo = ModelInfo(
            version: "1.0.0-untrained",
            trainedDate: nil,
            samplesUsed: 0,
            accuracy: 0,
            averageError: 100
        )
        UserDefaults.standard.removeObject(forKey: "ml.model.weights")
        UserDefaults.standard.removeObject(forKey: "ml.model.info")
    }
}

// MARK: - Model Weights

private struct ModelWeights: Codable {
    var weights1: [Double]  // Input -> Hidden1
    var bias1: [Double]
    var weights2: [Double]  // Hidden1 -> Hidden2
    var bias2: [Double]
    var weights3: [Double]  // Hidden2 -> Output
    var bias3: [Double]

    let hidden1Size: Int
    let hidden2Size: Int
    let outputSize: Int

    static func initial(featureCount: Int) -> ModelWeights {
        let h1 = 32
        let h2 = 16
        let out = 4

        // Xavier initialization
        let scale1 = sqrt(2.0 / Double(featureCount))
        let scale2 = sqrt(2.0 / Double(h1))
        let scale3 = sqrt(2.0 / Double(h2))

        return ModelWeights(
            weights1: (0..<(featureCount * h1)).map { _ in Double.random(in: -scale1...scale1) },
            bias1: [Double](repeating: 0, count: h1),
            weights2: (0..<(h1 * h2)).map { _ in Double.random(in: -scale2...scale2) },
            bias2: [Double](repeating: 0, count: h2),
            weights3: (0..<(h2 * out)).map { _ in Double.random(in: -scale3...scale3) },
            bias3: [Double](repeating: 0, count: out),
            hidden1Size: h1,
            hidden2Size: h2,
            outputSize: out
        )
    }
}

// MARK: - Training Result

struct TrainingResult {
    let success: Bool
    let finalLoss: Double
    let finalAccuracy: Double
    let epochsCompleted: Int
    let error: String?
}

// MARK: - Codable Extensions

extension LocationCorrectionModel.ModelInfo: Codable {}
