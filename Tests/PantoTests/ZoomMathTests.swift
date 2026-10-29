import XCTest
@testable import Panto

final class ZoomMathTests: XCTestCase {
    func testEmptyTimelineHasNoZoom() {
        let state = ZoomMath.state(at: 0, shots: [], maxZoom: 2)
        XCTAssertEqual(state.scale, 1)
        XCTAssertEqual(state.x, 0.5)
        XCTAssertEqual(state.y, 0.5)
    }

    func testClicksCloseInTimeAndSpaceMerge() {
        let events = [
            ZoomEvent(t: 1.0, x: 0.20, y: 0.20),
            ZoomEvent(t: 1.4, x: 0.22, y: 0.21)
        ]
        let shots = ZoomMath.shots(from: events)
        XCTAssertEqual(shots.count, 1)
        XCTAssertGreaterThan(shots[0].end, 2.0)
    }

    func testDistantClicksStaySeparate() {
        let events = [
            ZoomEvent(t: 1.0, x: 0.20, y: 0.20),
            ZoomEvent(t: 6.0, x: 0.80, y: 0.80)
        ]
        let shots = ZoomMath.shots(from: events)
        XCTAssertEqual(shots.count, 2)
        XCTAssertLessThan(shots[0].start, shots[1].start)
    }

    func testFullZoomAtShotCenter() {
        let shots = [ZoomShot(start: 2, end: 4, x: 0.3, y: 0.7)]
        let state = ZoomMath.state(at: 3, shots: shots, maxZoom: 2.4)
        XCTAssertEqual(state.scale, 2.4, accuracy: 0.001)
        XCTAssertEqual(state.x, 0.3, accuracy: 0.001)
        XCTAssertEqual(state.y, 0.7, accuracy: 0.001)
    }

    func testZoomReturnsToOneBetweenShots() {
        let shots = [
            ZoomShot(start: 1, end: 2, x: 0.2, y: 0.2),
            ZoomShot(start: 8, end: 9, x: 0.8, y: 0.8)
        ]
        let state = ZoomMath.state(at: 5, shots: shots, maxZoom: 2)
        XCTAssertEqual(state.scale, 1, accuracy: 0.0001)
    }

    func testWeightIsSymmetricAndBounded() {
        for t in stride(from: -1.0, through: 4.0, by: 0.05) {
            let w = ZoomMath.weight(at: t, start: 1, end: 2, fade: 0.3)
            XCTAssertGreaterThanOrEqual(w, 0)
            XCTAssertLessThanOrEqual(w, 1)
        }
        XCTAssertEqual(ZoomMath.weight(at: 1.5, start: 1, end: 2, fade: 0.3), 1, accuracy: 0.0001)
        XCTAssertEqual(ZoomMath.weight(at: 0.5, start: 1, end: 2, fade: 0.3), 0, accuracy: 0.0001)
    }

    func testSmoothstepClamps() {
        XCTAssertEqual(ZoomMath.smoothstep(-3), 0)
        XCTAssertEqual(ZoomMath.smoothstep(4), 1)
        XCTAssertEqual(ZoomMath.smoothstep(0.5), 0.5, accuracy: 0.0001)
    }

    func testTransformKeepsScaleAndOffsetsToCenter() {
        let size = CGSize(width: 1000, height: 500)
        let transform = ZoomMath.transform(scale: 2, centerX: 0.5, centerY: 0.5, size: size)
        XCTAssertEqual(transform.a, 2, accuracy: 0.0001)
        XCTAssertEqual(transform.d, 2, accuracy: 0.0001)
        // Zooming around the center of a 1000×500 frame moves it by half the size.
        XCTAssertEqual(transform.tx, -500, accuracy: 0.5)
        XCTAssertEqual(transform.ty, -250, accuracy: 0.5)
    }
}
