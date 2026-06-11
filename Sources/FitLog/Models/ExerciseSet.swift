import Foundation

struct ExerciseSet: Identifiable, Codable {
    let id: UUID
    var workoutId: UUID
    var exerciseName: String
    var weightKg: Double?
    var reps: Int
    var note: String?

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        exerciseName: String,
        weightKg: Double? = nil,
        reps: Int,
        note: String? = nil
    ) {
        self.id = id
        self.workoutId = workoutId
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.reps = reps
        self.note = note
    }
}
