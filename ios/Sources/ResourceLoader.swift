import MetalKit

/// Loads real converted Dungeon Keeper II resources from the app bundle.
/// Files live in Payload/DungeonKeeperII.app/Converted/... (see build-ios.yml).
enum ResourceError: Error {
    case missing(String)
}

final class ResourceLoader {
    private let device: MTLDevice
    private let loader: MTKTextureLoader

    init(device: MTLDevice) {
        self.device = device
        self.loader = MTKTextureLoader(device: device)
    }

    func texture(_ relativePath: String) throws -> MTLTexture {
        guard let url = Bundle.main.resourceURL?
                .appendingPathComponent("Converted", isDirectory: true)
                .appendingPathComponent(relativePath) else {
            throw ResourceError.missing(relativePath)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ResourceError.missing(url.path)
        }
        return try loader.newTexture(URL: url, options: [
            .generateMipmaps: true,
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
        ])
    }

    static func availableTextureNames() -> [String] {
        guard let dir = Bundle.main.resourceURL?
                .appendingPathComponent("Converted/Textures", isDirectory: true),
              let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return []
        }
        return files.filter { $0.lowercased().hasSuffix(".png") }
    }
}
