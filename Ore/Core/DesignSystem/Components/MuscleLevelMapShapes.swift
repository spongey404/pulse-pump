import SwiftUI

/// The design's body map ("BodyMap.dc.html"): a front and a back figure in a 160 × 292 box (viewBox
/// `20 10 160 292`), every muscle a path tinted by how hard the exercise works it.
enum MuscleLevelMapShapes {
    /// The part of the 200 × 320 drawing that is visible.
    static let viewBox = CGRect(x: 20, y: 10, width: 160, height: 292)

    /// Parts every figure has and that never change colour.
    static let head = (cx: 100.0, cy: 24.0, r: 13.0)
    static let neck = CGRect(x: 94, y: 36, width: 12, height: 8)
    static let feet = [(cx: 88.0, cy: 294.0, rx: 10.0, ry: 5.0), (cx: 112.0, cy: 294.0, rx: 10.0, ry: 5.0)]

    static let front: [(muscle: String, path: String)] = [
        ("traps", "M78 48 L100 43 L122 48 L118 56 L100 52 L82 56 Z"),
        ("chest", "M70 56 Q86 51 99 54 L99 92 Q84 96 69 91 Z"),
        ("chest", "M130 56 Q114 51 101 54 L101 92 Q116 96 131 91 Z"),
        ("frontDelts", "M62 57 Q56 72 56 90 L67 91 Q70 76 70 56 Z"),
        ("frontDelts", "M138 57 Q144 72 144 90 L133 91 Q130 76 130 56 Z"),
        ("sideDelts", "M62 57 Q50 64 50 88 L56 90 Q56 72 62 57 Z"),
        ("sideDelts", "M138 57 Q150 64 150 88 L144 90 Q144 72 138 57 Z"),
        ("biceps", "M42 92 Q36 110 38 130 L53 130 Q56 110 53 92 Z"),
        ("biceps", "M158 92 Q164 110 162 130 L147 130 Q144 110 147 92 Z"),
        ("forearms", "M34 132 Q28 154 31 174 L47 174 Q51 154 51 132 Z"),
        ("forearms", "M166 132 Q172 154 169 174 L153 174 Q149 154 149 132 Z"),
        ("abs", "M87 96 L113 96 L112 140 L88 140 Z"),
        ("obliques", "M71 95 L86 96 L87 140 L77 138 Z"),
        ("obliques", "M129 95 L114 96 L113 140 L123 138 Z"),
        ("quads", "M76 142 L99 146 Q101 190 98 230 L78 230 Q71 190 76 142 Z"),
        ("quads", "M124 142 L101 146 Q99 190 102 230 L122 230 Q129 190 124 142 Z"),
        ("calves", "M80 234 Q76 260 80 286 L96 286 Q98 260 96 234 Z"),
        ("calves", "M120 234 Q124 260 120 286 L104 286 Q102 260 104 234 Z"),
    ]

    static let back: [(muscle: String, path: String)] = [
        ("traps", "M80 47 L100 42 L120 47 L111 82 L100 90 L89 82 Z"),
        ("upperBack", "M72 56 L88 61 L89 82 L70 88 Q68 70 72 56 Z"),
        ("upperBack", "M128 56 L112 61 L111 82 L130 88 Q132 70 128 56 Z"),
        ("lats", "M70 88 L89 82 L96 120 L80 128 Q72 110 70 88 Z"),
        ("lats", "M130 88 L111 82 L104 120 L120 128 Q128 110 130 88 Z"),
        ("lowerBack", "M89 82 L100 90 L111 82 L104 120 L120 128 L122 138 L78 138 L80 128 L96 120 Z"),
        ("rearDelts", "M62 57 Q56 72 56 90 L70 88 Q68 70 72 56 Z"),
        ("rearDelts", "M138 57 Q144 72 144 90 L130 88 Q132 70 128 56 Z"),
        ("sideDelts", "M62 57 Q50 64 50 88 L56 90 Q56 72 62 57 Z"),
        ("sideDelts", "M138 57 Q150 64 150 88 L144 90 Q144 72 138 57 Z"),
        ("triceps", "M42 92 Q36 110 38 130 L53 130 Q56 110 53 92 Z"),
        ("triceps", "M158 92 Q164 110 162 130 L147 130 Q144 110 147 92 Z"),
        ("forearms", "M34 132 Q28 154 31 174 L47 174 Q51 154 51 132 Z"),
        ("forearms", "M166 132 Q172 154 169 174 L153 174 Q149 154 149 132 Z"),
        ("glutes", "M78 138 L99 138 L99 166 Q84 170 74 160 Z"),
        ("glutes", "M122 138 L101 138 L101 166 Q116 170 126 160 Z"),
        ("hamstrings", "M75 162 Q84 170 98 168 Q100 200 98 230 L78 230 Q71 200 75 162 Z"),
        ("hamstrings", "M125 162 Q116 170 102 168 Q100 200 102 230 L122 230 Q129 200 125 162 Z"),
        ("calves", "M80 234 Q75 255 80 286 L96 286 Q99 255 96 234 Z"),
        ("calves", "M120 234 Q125 255 120 286 L104 286 Q101 255 104 234 Z"),
    ]

    /// Muscle names the map knows (the keys of the design's `levels`).
    static let muscles: Set<String> = Set((front + back).map(\.muscle))
}
