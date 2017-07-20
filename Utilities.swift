//
//  Utilities.swift
//  ARDemo
//
//  Created by Anson Leung on 11/7/2017.
//  Copyright © 2017 Anson Leung. All rights reserved.
//

import Foundation
import ARKit
import UIKit

class Utilities: NSObject {

    static func intersection(u1: CGPoint, u2: CGPoint, v1: CGPoint, v2: CGPoint) -> CGPoint {
        var ret = u1
        let t = ((u1.x-v1.x)*(v1.y-v2.y)-(u1.y-v1.y)*(v1.x-v2.x))/((u1.x-u2.x)*(v1.y-v2.y)-(u1.y-u2.y)*(v1.x-v2.x))
        ret.x += (u2.x-u1.x)*t
        ret.y += (u2.y-u1.y)*t
        return ret
    }

}

extension CGPoint {
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let xDist = a.x - b.x
        let yDist = a.y - b.y
        return CGFloat(sqrt((xDist * xDist) + (yDist * yDist)))
    }
}

extension SCNVector3 {

    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }

    mutating func setLength(_ length: Float) {
        self.normalize()
        self *= length
    }

    static func positionFromTransform(_ transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    mutating func normalize() {
        self = self.normalized()
    }

    func normalized() -> SCNVector3 {
        if self.length() == 0 {
            return self
        }

        return self / self.length()
    }

    func dot(_ vec: SCNVector3) -> Float {
        return (self.x * vec.x) + (self.y * vec.y) + (self.z * vec.z)
    }

    func cross(_ vec: SCNVector3) -> SCNVector3 {
        return SCNVector3(self.y * vec.z - self.z * vec.y, self.z * vec.x - self.x * vec.z, self.x * vec.y - self.y * vec.x)
    }
    
    static func distance(_ v1:SCNVector3, _ v2:SCNVector3) -> Float {
        let vd = v1-v2
        let dist = vd.dot(vd)
        return dist
    }

    mutating func setMaximumLength(_ maxLength: Float) {
        if self.length() <= maxLength {
            return
        } else {
            self.normalize()
            self *= maxLength
        }
    }
}

extension ARSCNView {

    struct FeatureHitTestResult {
        let position: SCNVector3
        let distanceToRayOrigin: Float
        let featureHit: SCNVector3
        let featureDistanceToHitResult: Float
    }

    struct HitTestRay {
        let origin: SCNVector3
        let direction: SCNVector3
    }

    func hitTestRayFromScreenPos(_ point: CGPoint) -> HitTestRay? {

        guard let frame = self.session.currentFrame else {
            return nil
        }

        let cameraPos = SCNVector3.positionFromTransform(frame.camera.transform)

        // Note: z: 1.0 will unproject() the screen position to the far clipping plane.
        let positionVec = SCNVector3(x: Float(point.x), y: Float(point.y), z: 1.0)
        let screenPosOnFarClippingPlane = self.unprojectPoint(positionVec)

        var rayDirection = screenPosOnFarClippingPlane - cameraPos
        rayDirection.normalize()

        return HitTestRay(origin: cameraPos, direction: rayDirection)
    }

    func hitTestWithFeatures(_ point: CGPoint, coneOpeningAngleInDegrees: Float,
                             minDistance: Float = 0,
                             maxDistance: Float = Float.greatestFiniteMagnitude,
                             maxResults: Int = 1) -> [FeatureHitTestResult] {

        var results = [FeatureHitTestResult]()

        guard let features = self.session.currentFrame?.rawFeaturePoints else {
            return results
        }

        guard let ray = hitTestRayFromScreenPos(point) else {
            return results
        }

        let maxAngleInDeg = min(coneOpeningAngleInDegrees, 360) / 2
        let maxAngle = ((maxAngleInDeg / 180) * Float.pi)

        let points = features.points

        for i in 0...features.count {

            let feature = points.advanced(by: Int(i))
            let featurePos = SCNVector3(feature.pointee)

            let originToFeature = featurePos - ray.origin

            let crossProduct = originToFeature.cross(ray.direction)
            let featureDistanceFromResult = crossProduct.length()

            let hitTestResult = ray.origin + (ray.direction * ray.direction.dot(originToFeature))
            let hitTestResultDistance = (hitTestResult - ray.origin).length()

            if hitTestResultDistance < minDistance || hitTestResultDistance > maxDistance {
                // Skip this feature - it is too close or too far away.
                continue
            }

            let originToFeatureNormalized = originToFeature.normalized()
            let angleBetweenRayAndFeature = acos(ray.direction.dot(originToFeatureNormalized))

            if angleBetweenRayAndFeature > maxAngle {
                // Skip this feature - is is outside of the hit test cone.
                continue
            }

            // All tests passed: Add the hit against this feature to the results.
            results.append(FeatureHitTestResult(position: hitTestResult,
                                                distanceToRayOrigin: hitTestResultDistance,
                                                featureHit: featurePos,
                                                featureDistanceToHitResult: featureDistanceFromResult))
        }

        // Sort the results by feature distance to the ray.
        results = results.sorted(by: { (first, second) -> Bool in
            return first.distanceToRayOrigin < second.distanceToRayOrigin
        })

        // Cap the list to maxResults.
        var cappedResults = [FeatureHitTestResult]()
        var i = 0
        while i < maxResults && i < results.count {
            cappedResults.append(results[i])
            i += 1
        }

        return cappedResults
    }

    func hitTestWithInfiniteHorizontalPlane(_ point: CGPoint, _ pointOnPlane: SCNVector3) -> SCNVector3? {

        guard let ray = hitTestRayFromScreenPos(point) else {
            return nil
        }

        // Do not intersect with planes above the camera or if the ray is almost parallel to the plane.
        if ray.direction.y > -0.03 {
            return nil
        }

        // Return the intersection of a ray from the camera through the screen position with a horizontal plane
        // at height (Y axis).
        return rayIntersectionWithHorizontalPlane(rayOrigin: ray.origin, direction: ray.direction, planeY: pointOnPlane.y)
    }

    func hitTestFromOrigin(origin: SCNVector3, direction: SCNVector3) -> FeatureHitTestResult? {

        guard let features = self.session.currentFrame?.rawFeaturePoints else {
            return nil
        }

        let points = features.points

        // Determine the point from the whole point cloud which is closest to the hit test ray.
        var closestFeaturePoint = origin
        var minDistance = Float.greatestFiniteMagnitude

        for i in 0...features.count {
            let feature = points.advanced(by: Int(i))
            let featurePos = SCNVector3(feature.pointee)

            let originVector = origin - featurePos
            let crossProduct = originVector.cross(direction)
            let featureDistanceFromResult = crossProduct.length()

            if featureDistanceFromResult < minDistance {
                closestFeaturePoint = featurePos
                minDistance = featureDistanceFromResult
            }
        }

        // Compute the point along the ray that is closest to the selected feature.
        let originToFeature = closestFeaturePoint - origin
        let hitTestResult = origin + (direction * direction.dot(originToFeature))
        let hitTestResultDistance = (hitTestResult - origin).length()

        return FeatureHitTestResult(position: hitTestResult,
                                    distanceToRayOrigin: hitTestResultDistance,
                                    featureHit: closestFeaturePoint,
                                    featureDistanceToHitResult: minDistance)
    }

    func hitTestWithFeatures(_ point: CGPoint) -> [FeatureHitTestResult] {

        var results = [FeatureHitTestResult]()

        guard let ray = hitTestRayFromScreenPos(point) else {
            return results
        }

        if let result = self.hitTestFromOrigin(origin: ray.origin, direction: ray.direction) {
            results.append(result)
        }

        return results
    }
}

func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}

func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
}

func += (left: inout SCNVector3, right: SCNVector3) {
    left = left + right
}

func -= (left: inout SCNVector3, right: SCNVector3) {
    left = left - right
}

func / (left: SCNVector3, right: Float) -> SCNVector3 {
    return SCNVector3Make(left.x / right, left.y / right, left.z / right)
}

func * (left: SCNVector3, right: Float) -> SCNVector3 {
    return SCNVector3Make(left.x * right, left.y * right, left.z * right)
}

func /= (left: inout SCNVector3, right: Float) {
    left = left / right
}

func *= (left: inout SCNVector3, right: Float) {
    left = left * right
}

func rayIntersectionWithHorizontalPlane(rayOrigin: SCNVector3, direction: SCNVector3, planeY: Float) -> SCNVector3? {

    let direction = direction.normalized()

    // Special case handling: Check if the ray is horizontal as well.
    if direction.y == 0 {
        if rayOrigin.y == planeY {
            // The ray is horizontal and on the plane, thus all points on the ray intersect with the plane.
            // Therefore we simply return the ray origin.
            return rayOrigin
        } else {
            // The ray is parallel to the plane and never intersects.
            return nil
        }
    }

    // The distance from the ray's origin to the intersection point on the plane is:
    //   (pointOnPlane - rayOrigin) dot planeNormal
    //  --------------------------------------------
    //          direction dot planeNormal

    // Since we know that horizontal planes have normal (0, 1, 0), we can simplify this to:
    let dist = (planeY - rayOrigin.y) / direction.y

    // Do not return intersections behind the ray's origin.
    if dist < 0 {
        return nil
    }

    // Return the intersection point.
    return rayOrigin + (direction * dist)
}

// MARK: Collection extensions
extension Array where Iterator.Element == CGFloat {
    var average: CGFloat? {
        guard !isEmpty else {
            return nil
        }

        var ret = self.reduce(CGFloat(0)) { (cur, next) -> CGFloat in
            var cur = cur
            cur += next
            return cur
        }
        let fcount = CGFloat(count)
        ret /= fcount
        return ret
    }
}

extension RangeReplaceableCollection where IndexDistance == Int {
    mutating func keepLast(_ elementsToKeep: Int) {
        if count > elementsToKeep {
            self.removeFirst(count - elementsToKeep)
        }
    }
}

// @from https://gist.github.com/blender/a75f589e6bd86aa2121618155cbdf827
extension FileManager {
    
    /// This method calculates the accumulated size of a directory on the volume in bytes.
    ///
    /// As there's no simple way to get this information from the file system it has to crawl the entire hierarchy,
    /// accumulating the overall sum on the way. The resulting value is roughly equivalent with the amount of bytes
    /// that would become available on the volume if the directory would be deleted.
    ///
    /// - note: There are a couple of oddities that are not taken into account (like symbolic links, meta data of
    /// directories, hard links, ...).
    
    public func allocatedSizeOfDirectory(atUrl url: URL) throws -> UInt64 {
        
        // We'll sum up content size here:
        var accumulatedSize: UInt64 = 0
        
        // prefetching some properties during traversal will speed up things a bit.
        
        let prefetchedProperties = [
            URLResourceKey.isRegularFileKey
            , URLResourceKey.fileAllocatedSizeKey
            , URLResourceKey.totalFileAllocatedSizeKey
        ]
        
        // The error handler simply signals errors to outside code.
        var errorDidOccur: Error?
        let errorHandler: (URL, Error) -> Bool = { _, error in
            errorDidOccur = error
            return false
        }
        
        
        // We have to enumerate all directory contents, including subdirectories.
        let enumerator = self.enumerator(at: url,
                                         includingPropertiesForKeys: prefetchedProperties,
                                         options: FileManager.DirectoryEnumerationOptions.init(rawValue: 0),
                                         errorHandler: errorHandler)
        
        // Start the traversal:
        while let contentURL = (enumerator?.nextObject() as? URL)  {
            
            // Bail out on errors from the errorHandler.
            if let error = errorDidOccur { throw error }
            
            // Get the type of this item, making sure we only sum up sizes of regular files.
            let resourceValues = try contentURL.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            
            guard resourceValues.isRegularFile ?? false else {
                continue
            }
            
            // To get the file's size we first try the most comprehensive value in terms of what the file may use on disk.
            // This includes metadata, compression (on file system level) and block size.
            var fileSize = resourceValues.fileSize
            
            // In case the value is unavailable we use the fallback value (excluding meta data and compression)
            // This value should always be available.
            fileSize = fileSize ?? resourceValues.totalFileAllocatedSize
            
            // We're good, add up the value.
            accumulatedSize += UInt64(fileSize ?? 0)
        }
        
        // Bail out on errors from the errorHandler.
        if let error = errorDidOccur { throw error }
        
        // We finally got it.
        return accumulatedSize
    }
}
